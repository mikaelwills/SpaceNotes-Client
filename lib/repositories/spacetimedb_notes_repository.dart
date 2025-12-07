import 'dart:async';
import 'dart:developer';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show ConnectionConfig;
import 'package:uuid/uuid.dart';
import '../generated/client.dart';
import '../generated/note.dart';
import '../generated/folder.dart';
import 'notes_repository.dart';
import 'shared_preferences_token_store.dart';
import 'package:rxdart/rxdart.dart';

/// Notes repository implementation using SpacetimeDB
class SpacetimeDbNotesRepository implements NotesRepository {
  // Configuration
  String? _host;
  String? _database;
  stdb.AuthTokenStore? _authStorage;

  // Client
  SpacetimeDbClient? _client;
  Future<void>? _connectingFuture;

  // Stream for reactive updates
  final _notesSubject = BehaviorSubject<List<Note>>.seeded([]);

  // Stream for folders only
  final _foldersSubject = BehaviorSubject<List<Folder>>.seeded([]);

  // Stream for client changes (emits when client is created/reset)
  final _clientSubject = BehaviorSubject<SpacetimeDbClient?>.seeded(null);

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  SpacetimeDbNotesRepository({
    String? host,
    String? database,
    stdb.AuthTokenStore? authStorage,
  })  : _host = host,
        _database = database,
        _authStorage = authStorage;

  /// Ensure client is connected
  Future<void> _ensureConnected() async {
    bool wasDegraded = false;

    // If client exists, check if connection is actually healthy
    if (_client != null) {
      final status = _client!.connection.status;

      // Only proceed if fully connected
      if (status == stdb.ConnectionStatus.connected) {
        return;
      }

      // Connection degraded - log and attempt reconnect
      print('🔥 DEGRADED CONNECTION DETECTED: $status');
      wasDegraded = true;

      // Reset and reconnect
      resetConnection();
      // Fall through to connection logic below
    }

    // If connection in progress, wait for it
    if (_connectingFuture != null) {
      await _connectingFuture;
      return;
    }

    final configured = await isConfigured();

    if (!configured) {
      return;
    }

    // Start connection and store the future to prevent race conditions
    _connectingFuture = _connect();
    try {
      await _connectingFuture;

      // Log result if we recovered from degraded state
      if (wasDegraded) {
        if (_client != null && _client!.connection.status == stdb.ConnectionStatus.connected) {
          print('🔥 RECONNECTION SUCCESSFUL');
        } else {
          print('🔥 RECONNECTION FAILED');
        }
      }
    } finally {
      _connectingFuture = null;
    }
  }

  Future<void> _connect() async {
    try {
      print('  Attempting to connect to SpacetimeDB:');
      print('    host: $_host');
      print('    database: $_database');
      print('    authStorage provided: ${_authStorage != null}');

      final storage = _authStorage ?? SharedPreferencesTokenStore();

      // Aggressive connection health monitoring to prevent "zombie connections"
      // - pingInterval: 4s (fast feedback for connection health)
      // - pongTimeout: 5s (quickly kill connections that don't respond)
      // - autoReconnect: true (automatically recover from connection failures)
      try {
        _client = await SpacetimeDbClient.connect(
          host: _host!,
          database: _database!,
          authStorage: storage,
          ssl: false, // Local network connection
          initialSubscriptions: ['SELECT * FROM note', 'SELECT * FROM folder'],
          config: const ConnectionConfig(
            pingInterval: Duration(seconds: 4),
            pongTimeout: Duration(seconds: 5),
            autoReconnect: true,
          ),
        );
      } catch (e) {
        // Check for HTTP 401 (auth failure - stale/invalid token)
        // SpacetimeDB rejects auth at HTTP level before WebSocket upgrade
        if (e.toString().contains('401')) {
          print('  ⚠️ Auth failure (HTTP 401) - clearing token and retrying...');
          await storage.clearToken();

          // Retry connection with fresh anonymous identity
          _client = await SpacetimeDbClient.connect(
            host: _host!,
            database: _database!,
            authStorage: storage,
            ssl: false,
            initialSubscriptions: ['SELECT * FROM note', 'SELECT * FROM folder'],
            config: const ConnectionConfig(
              pingInterval: Duration(seconds: 4),
              pongTimeout: Duration(seconds: 5),
              autoReconnect: true,
            ),
          );
          print('  ✅ Reconnected with fresh anonymous identity');
        } else {
          // Not an auth error - rethrow (network failure, config error, etc.)
          rethrow;
        }
      }

      // Emit new client to stream
      _clientSubject.add(_client);

      print('  ✅ Successfully connected to SpacetimeDB');
      print('  Tables registered and initial data loaded');

      // Register stream listeners for reactive updates
      print('  Registering stream listeners for real-time updates...');
      _registerStreamListeners();

      // Ensure All Notes folder exists and migrate any root-level notes
      await ensureGeneralNotesFolder();
    } catch (e) {
      print('  ❌ Error connecting to SpacetimeDB: $e');
      print('  Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Register stream listeners on the Note and Folder tables to emit stream updates
  ///
  /// Uses event streams to filter out local UPDATE transactions (echoes of our own changes)
  /// so the UI only sees genuine remote updates. Inserts and Deletes always pass through
  /// to ensure the UI gets server-assigned IDs and deletion notifications.
  void _registerStreamListeners() {
    if (_client == null) return;

    final noteTable = _client!.note;
    final folderTable = _client!.folder;

    // Listen to note insert event stream - ALWAYS emit (UI needs server-assigned ID)
    final noteInsertSub = noteTable.insertEventStream.listen((event) {
      final isMyChange = event.context.isMyTransaction;
      if (!isMyChange) {
        print('⚠️ [REMOTE] Note inserted: ${event.row.path}');
      }
      _emitCurrentNotes(); // Always emit for inserts
    });
    _subscriptions.add(noteInsertSub);

    // Listen to note update event stream - always emit to keep cache fresh
    final noteUpdateSub = noteTable.updateEventStream.listen((event) {
      _emitCurrentNotes(); // Always emit - UI handles focus protection
    });
    _subscriptions.add(noteUpdateSub);

    // Listen to note delete event stream - always emit to keep cache fresh
    // Note: SpacetimeDB implements updates as delete+insert
    final noteDeleteSub = noteTable.deleteEventStream.listen((event) {
      _emitCurrentNotes(); // Always emit - UI handles focus protection
    });
    _subscriptions.add(noteDeleteSub);

    // Listen to folder insert event stream - ALWAYS emit
    final folderInsertSub = folderTable.insertEventStream.listen((event) {
      final isMyChange = event.context.isMyTransaction;
      print('📡 Stream: Folder inserted (path: ${event.row.path}) [${isMyChange ? "local" : "remote"}]');
      _emitCurrentNotes(); // Always emit for inserts
    });
    _subscriptions.add(folderInsertSub);

    // Listen to folder update event stream - filter local echoes
    final folderUpdateSub = folderTable.updateEventStream.listen((event) {
      final isMyChange = event.context.isMyTransaction;
      print('📡 Stream: Folder updated (path: ${event.newRow.path}) [${isMyChange ? "local" : "remote"}]');
      if (!isMyChange) {
        _emitCurrentNotes(); // Only emit for remote updates
      }
    });
    _subscriptions.add(folderUpdateSub);

    // Listen to folder delete event stream - ALWAYS emit
    final folderDeleteSub = folderTable.deleteEventStream.listen(
      (event) {
        final isMyChange = event.context.isMyTransaction;
        print('📡 Stream: Folder deleted (path: ${event.row.path}) [${isMyChange ? "local" : "remote"}]');
        _emitCurrentNotes(); // Always emit for deletes
      },
      onError: (error) {
        print('❌ Error in folder delete stream: $error');
      },
      onDone: () {
        print('⚠️ Folder delete stream closed');
      },
    );
    _subscriptions.add(folderDeleteSub);

    print('  ✅ Stream listeners registered (event streams with local update filtering)');
  }

  /// Watch notes list for real-time updates
  ///
  /// Returns a stream that emits List<Note> whenever the note cache is updated
  Stream<List<Note>> watchNotesList() {
    print('SpacetimeDbNotesRepository.watchNotesList() called');
    return _notesSubject.stream;
  }

  /// Watch folders list for real-time updates
  ///
  /// Returns a stream that emits List<Folder> whenever the folder cache is updated
  Stream<List<Folder>> watchFoldersList() {
    print('SpacetimeDbNotesRepository.watchFoldersList() called');
    return _foldersSubject.stream;
  }

  /// Watch client changes for connection monitoring
  ///
  /// Returns a stream that emits SpacetimeDbClient? whenever the client is created or reset
  Stream<SpacetimeDbClient?> watchClient() {
    return _clientSubject.stream;
  }

  /// Get current notes synchronously
  List<Note> get currentNotes => _notesSubject.value;

  /// Get current folders synchronously
  List<Folder> get currentFolders => _foldersSubject.value;

  /// Get note update event stream with transaction context
  ///
  /// Use this to check isMyTransaction for distinguishing local echoes from remote changes
  Stream<stdb.TableUpdateEvent<Note>>? get noteUpdateEvents => _client?.note.updateEventStream;

  /// Get note delete event stream with transaction context
  Stream<stdb.TableDeleteEvent<Note>>? get noteDeleteEvents => _client?.note.deleteEventStream;

  /// Query current cache and emit to streams
  void _emitCurrentNotes() {
    if (_client == null) return;

    try {
      final noteTable = _client!.note;
      final folderTable = _client!.folder;

      final notes = noteTable.iter().toList();
      final folders = folderTable.iter().toList();

      // Sort notes by name
      notes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Sort folders by path
      folders.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      _notesSubject.add(notes);
      _foldersSubject.add(folders);
    } catch (e) {
      print('  ❌ Error emitting to streams: $e');
      _notesSubject.addError(e);
      _foldersSubject.addError(e);
    }
  }


  @override
  Future<bool> isConfigured() async {
    final configured = _host != null && _host!.isNotEmpty;
    print('SpacetimeDbNotesRepository.isConfigured() = $configured');
    return configured;
  }

  @override
  Future<bool> checkConnection() async {
    if (_client == null) {
      return false;
    }

    final isConnected =
        _client!.connection.status == stdb.ConnectionStatus.connected;
    return isConnected;
  }


  @override
  Future<Note?> getNote(String id) async {
    try {
      await _ensureConnected();

      if (_client == null) return null;

      // Find note by id (id is the primary key)
      final noteTable = _client!.note;
      final note = noteTable.find(id);

      return note;
    } catch (e) {
      log('Error loading note from SpacetimeDB: $e');
      return null;
    }
  }

  @override
  Future<String?> createNote(String path, String content) async {
    try {
      await _ensureConnected();

      if (_client == null) {
        return null;
      }

      // Generate UUID for the note
      const uuid = Uuid();
      final id = uuid.v4();

      // Extract name from path (e.g., "folder/My Note.md" -> "My Note")
      final name = path.split('/').last.replaceAll('.md', '');

      // Extract folder path (e.g., "folder/subfolder/note.md" -> "folder/subfolder/")
      final pathParts = path.split('/');
      final folderPath = pathParts.length > 1
          ? '${pathParts.sublist(0, pathParts.length - 1).join('/')}/'
          : '';

      // Calculate depth (number of folders in path, not counting the note itself)
      // Root notes (no folders) = depth 0
      // Notes in "folder/" = depth 1
      // Notes in "folder/subfolder/" = depth 2
      final depth = folderPath.isEmpty
          ? 0
          : folderPath.split('/').where((s) => s.isNotEmpty).length;

      final now = DateTime.now().millisecondsSinceEpoch;

      await _client!.reducers.createNote(
        id: id,
        path: path,
        name: name,
        content: content,
        folderPath: folderPath,
        depth: depth,
        frontmatter: '', // Empty frontmatter for new notes
        size: content.length,
        createdTime: now,
        modifiedTime: now,
      );

      return id;
    } catch (e) {
      print('  ❌ Error creating note: $e');
      return null;
    }
  }

  @override
  Future<bool> updateNote(String id, String content) async {
    try {
      await _ensureConnected();

      if (_client == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;

      await _client!.reducers.updateNoteContent(
        id: id,
        content: content,
        frontmatter: '', // TODO: Parse frontmatter from content if needed
        size: content.length,
        modifiedTime: now,
      );

      return true;
    } catch (e) {
      print('❌ [CONTENT UPDATE] Error updating note content: $e');
      log('Error updating note content in SpacetimeDB: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteNote(String id) async {
    print('SpacetimeDbNotesRepository.deleteNote() called');
    print('  id: $id');

    try {
      await _ensureConnected();

      if (_client == null) {
        print('  ❌ Client is null, cannot delete note');
        return false;
      }

      print('  Calling SpacetimeDB reducer deleteNote...');
      await _client!.reducers.deleteNote(id: id);

      print('  ✅ Successfully deleted note: $id');
      return true;
    } catch (e) {
      print('  ❌ Error deleting note in SpacetimeDB: $e');
      print('  Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Rename/move a note to a new path
  Future<bool> renameNote(String id, String newPath) async {
    try {
      await _ensureConnected();

      if (_client == null) {
        return false;
      }

      await _client!.reducers.renameNote(id: id, newPath: newPath);

      return true;
    } catch (e) {
      print('❌ [RENAME] Error renaming note: $e');
      return false;
    }
  }

  /// Ensure the All Notes folder exists and migrate any root-level notes into it
  Future<void> ensureGeneralNotesFolder() async {
    print('SpacetimeDbNotesRepository.ensureGeneralNotesFolder() called');

    try {
      await _ensureConnected();

      if (_client == null) {
        print('  ❌ Client is null, cannot ensure All Notes folder');
        return;
      }

      const generalNotesPath = 'All Notes';

      // Check if All Notes folder exists
      final folderTable = _client!.folder;
      final exists = folderTable.iter().any((f) => f.path == generalNotesPath);

      if (!exists) {
        print('  Creating All Notes folder...');
        await _client!.reducers.upsertFolder(
          path: generalNotesPath,
          name: 'All Notes',
          depth: 0,
        );
        print('  ✅ Created All Notes folder');
      } else {
        print('  ✓ All Notes folder already exists');
      }

      // Find all root-level notes (depth 0, empty folderPath)
      final noteTable = _client!.note;
      final rootNotes = noteTable
          .iter()
          .where((note) => note.folderPath.isEmpty || note.depth == 0)
          .toList();

      if (rootNotes.isNotEmpty) {
        print('  Found ${rootNotes.length} root-level notes to migrate');

        for (final note in rootNotes) {
          final newPath = 'All Notes/${note.path}';
          print('    Moving ${note.path} -> $newPath');
          await _client!.reducers.moveNote(
            oldPath: note.path,
            newPath: newPath,
          );
        }

        print('  ✅ Migrated ${rootNotes.length} notes to All Notes');
      } else {
        print('  ✓ No root-level notes to migrate');
      }
    } catch (e) {
      print('  ❌ Error ensuring All Notes folder: $e');
      print('  Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Future<bool> patchNote({
    required String path,
    required String content,
    int? position,
    String? heading,
  }) async {
    // Not supported in current SpacetimeDB schema
    log('Patch note not supported in SpacetimeDB');
    return false;
  }

  /// Create a new folder
  Future<bool> createFolder(String path) async {
    print('SpacetimeDbNotesRepository.createFolder() called');
    print('  path: $path');

    try {
      await _ensureConnected();

      if (_client == null) {
        print('  ❌ Client is null, cannot create folder');
        return false;
      }

      // Normalize path to NO trailing slash (standard)
      final normalizedPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      // Extract folder name from path
      final name = normalizedPath.split('/').last;

      // Calculate depth (number of parent folders)
      final depth = normalizedPath.split('/').length - 1;

      print('  Calling SpacetimeDB reducer upsertFolder...');
      await _client!.reducers.upsertFolder(
        path: normalizedPath,
        name: name,
        depth: depth,
      );

      print('  ✅ Successfully created folder: $normalizedPath');
      return true;
    } catch (e) {
      print('  ❌ Error creating folder in SpacetimeDB: $e');
      print('  Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Delete a folder (will cascade delete all notes and subfolders)
  Future<bool> deleteFolder(String path) async {
    print('SpacetimeDbNotesRepository.deleteFolder() called');
    print('  path: $path');

    try {
      await _ensureConnected();

      if (_client == null) {
        print('  ❌ Client is null, cannot delete folder');
        return false;
      }

      // Normalize path to NO trailing slash (standard)
      final normalizedPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      print('  Calling SpacetimeDB reducer deleteFolder...');
      await _client!.reducers.deleteFolder(path: normalizedPath);

      print('  ✅ Successfully deleted folder: $normalizedPath');

      // Debug: Check folder table state after delete
      final folderTable = _client!.folder;
      final allFolders = folderTable.iter().toList();
      final folderCount = allFolders.length;
      final stillExists = allFolders.any((f) => f.path == normalizedPath);
      print('  📊 Debug: Folder table count: $folderCount');
      print('  📊 Debug: Folder still in cache: $stillExists');
      print('  📊 Debug: All folder paths: ${allFolders.map((f) => f.path).toList()}');

      return true;
    } catch (e) {
      print('  ❌ Error deleting folder in SpacetimeDB: $e');
      print('  Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Move a folder to a new path (will cascade move all notes and subfolders)
  Future<bool> moveFolder(String oldPath, String newPath) async {
    print('SpacetimeDbNotesRepository.moveFolder() called');
    print('  oldPath: $oldPath');
    print('  newPath: $newPath');

    try {
      await _ensureConnected();

      if (_client == null) {
        print('  ❌ Client is null, cannot move folder');
        return false;
      }

      // Normalize paths to NO trailing slash (standard)
      final normalizedOldPath = oldPath.endsWith('/') ? oldPath.substring(0, oldPath.length - 1) : oldPath;
      final normalizedNewPath = newPath.endsWith('/') ? newPath.substring(0, newPath.length - 1) : newPath;

      print('  Calling SpacetimeDB reducer moveFolder...');
      await _client!.reducers.moveFolder(
        oldPath: normalizedOldPath,
        newPath: normalizedNewPath,
      );

      print('  ✅ Successfully moved folder: $normalizedOldPath -> $normalizedNewPath');
      return true;
    } catch (e) {
      print('  ❌ Error moving folder in SpacetimeDB: $e');
      print('  Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    try {
      await _ensureConnected();

      if (_client == null) return [];

      // Get all notes and filter locally
      final noteTable = _client!.note;
      final notes = noteTable.iter().toList();

      final queryLower = query.toLowerCase();

      final matchingNotes = notes
          .where((note) {
            return note.name.toLowerCase().contains(queryLower) ||
                note.content.toLowerCase().contains(queryLower) ||
                note.path.toLowerCase().contains(queryLower);
          })
          .toList();

      return matchingNotes;
    } catch (e) {
      log('Error searching notes in SpacetimeDB: $e');
      return [];
    }
  }

  /// Connect to SpacetimeDB and get initial data
  ///
  /// This ensures the client is connected, callbacks are registered,
  /// and emits the initial cache data to the stream
  Future<void> connectAndGetInitialData() async {
    print('SpacetimeDbNotesRepository.connectAndGetInitialData() called');
    await _ensureConnected();

    // Emit current cache data after connection
    _emitCurrentNotes();
  }

  /// Update configuration when connecting to a new instance
  void updateConfiguration({
    required String host,
    String? database,
    stdb.AuthTokenStore? authStorage,
  }) {
    print('SpacetimeDbNotesRepository.updateConfiguration() called');
    print('  new host: $host');
    print('  new database: $database');
    print('  new authStorage provided: ${authStorage != null}');

    // Store new configuration
    _host = host;
    _database = database;
    _authStorage = authStorage;

    // Reset connection so next operation will use new config
    resetConnection();

    print('  ✅ Configuration updated');
  }

  /// Reset the repository connection (used when switching instances)
  void resetConnection() {
    print('SpacetimeDbNotesRepository.resetConnection() called');
    print('  Disconnecting and clearing existing client...');

    // Cancel all stream subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Disconnect existing client if any
    if (_client != null) {
      try {
        _client!.disconnect();
      } catch (e) {
        print('  Error disconnecting client: $e');
      }
      _client = null;

      // Emit null to stream to notify listeners
      _clientSubject.add(null);
    }

    // Cancel any pending connection
    _connectingFuture = null;

    print('  ✅ Repository connection reset');
  }

  /// Get the current client (for connection state monitoring)
  SpacetimeDbClient? get client => _client;

  /// Get current configuration
  String? get host => _host;
  String? get database => _database;
  stdb.AuthTokenStore? get authStorage => _authStorage;

  /// Dispose resources
  void dispose() {
    print('SpacetimeDbNotesRepository.dispose() called');
    resetConnection();
    _notesSubject.close();
    _foldersSubject.close();
    _clientSubject.close();
  }
}
