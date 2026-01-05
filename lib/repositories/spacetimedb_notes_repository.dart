import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../services/debug_logger.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart'
    show
        ConnectionConfig,
        Int64,
        OfflineStorage,
        JsonFileStorage,
        InMemoryOfflineStorage,
        SyncState,
        OptimisticChange,
        SpacetimeDbAuthException;
import 'package:uuid/uuid.dart';
import '../generated/client.dart';
import '../generated/note.dart';
import '../generated/folder.dart';
import 'shared_preferences_token_store.dart';
import 'package:rxdart/rxdart.dart';

String _contentHash(String content) {
  final bytes = utf8.encode(content);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}

/// Notes repository implementation using SpacetimeDB
class SpacetimeDbNotesRepository {
  // Configuration
  String? _host;
  String? _database;
  stdb.AuthTokenStore? _authStorage;
  OfflineStorage? _offlineStorage;

  // Client
  SpacetimeDbClient? _client;
  Future<void>? _connectingFuture;

  // Stream for reactive updates
  final _notesSubject = BehaviorSubject<List<Note>>.seeded([]);

  // Stream for folders only
  final _foldersSubject = BehaviorSubject<List<Folder>>.seeded([]);

  // Stream for client changes (emits when client is created/reset)
  final _clientSubject = BehaviorSubject<SpacetimeDbClient?>.seeded(null);

  // Stream for sync state changes
  final _syncStateSubject =
      BehaviorSubject<SyncState>.seeded(const SyncState());

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Track if initial sync is complete to avoid spamming logs
  bool _initialSyncComplete = false;

  SpacetimeDbNotesRepository({
    String? host,
    String? database,
    stdb.AuthTokenStore? authStorage,
  })  : _host = host,
        _database = database,
        _authStorage = authStorage;

  Future<void> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('spacenotes_host');
    if (savedHost != null && savedHost.isNotEmpty) {
      final isValidUtf16 = savedHost.runes.every((r) => r <= 0x10FFFF);
      if (isValidUtf16 && RegExp(r'^[\x20-\x7E]+$').hasMatch(savedHost)) {
        _host = savedHost;
        debugLogger.info('REPO', 'Loaded saved host: $savedHost');
      } else {
        debugLogger.warning('REPO', 'Invalid saved host data, clearing');
        await prefs.remove('spacenotes_host');
      }
    }
  }

  /// Ensure client is available (connected or offline-ready)
  Future<void> _ensureConnected() async {
    if (_client != null) {
      final status = _client!.connection.status;

      if (status == stdb.ConnectionStatus.connected) {
        return;
      }

      if (status == stdb.ConnectionStatus.reconnecting ||
          status == stdb.ConnectionStatus.connecting) {
        debugLogger.connection('In progress ($status), client available for offline ops');
        return;
      }

      if (status == stdb.ConnectionStatus.disconnected) {
        if (_client!.hasOfflineStorage) {
          debugLogger.connection('Offline mode: using existing client');
          return;
        }
        debugLogger.warning('CONN', 'DEGRADED CONNECTION: $status');
        resetConnection();
      }
    }

    if (_connectingFuture != null) {
      await _connectingFuture;
      return;
    }

    final configured = await isConfigured();

    if (!configured) {
      return;
    }

    _connectingFuture = _connect();
    try {
      await _connectingFuture;
    } finally {
      _connectingFuture = null;
    }
  }

  Future<OfflineStorage?> _createOfflineStorage() async {
    if (kIsWeb) {
      debugLogger.info('STORAGE', 'Web platform - using InMemoryOfflineStorage');
      return InMemoryOfflineStorage();
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final storagePath = '${appDir.path}/spacenotes_offline';
      debugLogger.info('STORAGE', 'Native platform - using JsonFileStorage', storagePath);
      final storage = JsonFileStorage(basePath: storagePath);
      await storage.initialize();
      return storage;
    } catch (e) {
      debugLogger.error('STORAGE', 'Failed to create offline storage', e.toString());
      return null;
    }
  }

  Future<void> _connect() async {
    try {
      debugLogger.connection('Connecting to SpacetimeDB', 'host=$_host, db=$_database');

      final storage = _authStorage ?? SharedPreferencesTokenStore();

      _offlineStorage ??= await _createOfflineStorage();

      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          _client = await SpacetimeDbClient.connect(
            host: _host!,
            database: _database!,
            authStorage: storage,
            offlineStorage: _offlineStorage,
            ssl: false,
            initialSubscriptions: [
              'SELECT * FROM note',
              'SELECT * FROM folder'
            ],
            subscriptionTimeout: const Duration(seconds: 10),
            config: const ConnectionConfig(
              pingInterval: Duration(seconds: 4),
              pongTimeout: Duration(seconds: 5),
              autoReconnect: true,
              connectTimeout: Duration(seconds: 5),
            ),
            onCacheLoaded: (client) {
              debugLogger.sync('Offline cache loaded, emitting data');
              _client = client;
              _clientSubject.add(client);
              _registerStreamListeners();
              _emitCurrentNotes();
            },
          );
          break;
        } on SpacetimeDbAuthException {
          debugLogger.warning('AUTH', 'Auth failure (401) - clearing token and retrying');
          await storage.clearToken();
          _client = await SpacetimeDbClient.connect(
            host: _host!,
            database: _database!,
            authStorage: storage,
            offlineStorage: _offlineStorage,
            ssl: false,
            initialSubscriptions: [
              'SELECT * FROM note',
              'SELECT * FROM folder'
            ],
            subscriptionTimeout: const Duration(seconds: 10),
            config: const ConnectionConfig(
              pingInterval: Duration(seconds: 4),
              pongTimeout: Duration(seconds: 5),
              autoReconnect: true,
              connectTimeout: Duration(seconds: 5),
            ),
            onCacheLoaded: (client) {
              debugLogger.sync('Offline cache loaded, emitting data');
              _client = client;
              _clientSubject.add(client);
              _registerStreamListeners();
              _emitCurrentNotes();
            },
          );
          debugLogger.connection('Reconnected with fresh anonymous identity');
          break;
        } catch (e) {
          if (attempt < maxRetries) {
            debugLogger.warning('CONN', 'Attempt $attempt failed: $e, retrying in ${retryDelay.inSeconds}s');
            await Future.delayed(retryDelay);
          } else {
            rethrow;
          }
        }
      }

      _clientSubject.add(_client);

      final isConnected =
          _client!.connection.status == stdb.ConnectionStatus.connected;
      if (isConnected) {
        debugLogger.connection('Successfully connected to SpacetimeDB');
      } else {
        debugLogger.connection('Operating in offline mode (cached data available)');
      }

      _initialSyncComplete = true;

      _registerStreamListeners();

      if (isConnected) {
        await ensureGeneralNotesFolder();
      }
    } catch (e) {
      debugLogger.error('CONN', 'Error connecting to SpacetimeDB', e.toString());
      rethrow;
    }
  }

  bool _streamListenersRegistered = false;

  /// Register stream listeners on the Note and Folder tables to emit stream updates
  ///
  /// Uses event streams to filter out local UPDATE transactions (echoes of our own changes)
  /// so the UI only sees genuine remote updates. Inserts and Deletes always pass through
  /// to ensure the UI gets server-assigned IDs and deletion notifications.
  void _registerStreamListeners() {
    if (_client == null) return;
    if (_streamListenersRegistered) return;
    _streamListenersRegistered = true;

    final noteTable = _client!.note;
    final folderTable = _client!.folder;

    final noteInsertSub = noteTable.insertEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      final note = event.row;
      debugLogger.sync('Received insert: id=${note.id.substring(0, 8)}, path=${note.path}, len=${note.content.length}, hash=${_contentHash(note.content)}');
      _emitCurrentNotes();
    });
    _subscriptions.add(noteInsertSub);

    final noteUpdateSub = noteTable.updateEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      final note = event.newRow;
      debugLogger.sync('Received update: id=${note.id.substring(0, 8)}, len=${note.content.length}, hash=${_contentHash(note.content)}');
      _emitCurrentNotes();
    });
    _subscriptions.add(noteUpdateSub);

    final noteDeleteSub = noteTable.deleteEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      debugLogger.sync('Note DELETE: ${event.row.path}');
      _emitCurrentNotes();
    });
    _subscriptions.add(noteDeleteSub);

    final folderInsertSub = folderTable.insertEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      _emitCurrentNotes();
    });
    _subscriptions.add(folderInsertSub);

    final folderUpdateSub = folderTable.updateEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      if (!event.context.isMyTransaction) {
        _emitCurrentNotes();
      }
    });
    _subscriptions.add(folderUpdateSub);

    final folderDeleteSub = folderTable.deleteEventStream.listen((event) {
      if (!_initialSyncComplete) return;
      _emitCurrentNotes();
    });
    _subscriptions.add(folderDeleteSub);

    if (_client!.hasOfflineStorage) {
      final syncStateSub = _client!.onSyncStateChanged.listen((state) {
        _syncStateSubject.add(state);
      });
      _subscriptions.add(syncStateSub);
      _syncStateSubject.add(_client!.syncState);
    }

    debugLogger.sync('Stream listeners registered');
  }

  /// Watch notes list for real-time updates
  ///
  /// Returns a stream that emits List<Note> whenever the note cache is updated
  Stream<List<Note>> watchNotesList() {
    debugLogger.debug('REPO', 'watchNotesList() called');
    return _notesSubject.stream;
  }

  /// Watch folders list for real-time updates
  ///
  /// Returns a stream that emits List<Folder> whenever the folder cache is updated
  Stream<List<Folder>> watchFoldersList() {
    debugLogger.debug('REPO', 'watchFoldersList() called');
    return _foldersSubject.stream;
  }

  /// Watch client changes for connection monitoring
  ///
  /// Returns a stream that emits SpacetimeDbClient? whenever the client is created or reset
  Stream<SpacetimeDbClient?> watchClient() {
    return _clientSubject.stream;
  }

  /// Watch sync state for offline mutation status
  ///
  /// Returns a stream that emits SyncState whenever the sync status changes
  Stream<SyncState> watchSyncState() {
    return _syncStateSubject.stream;
  }

  /// Get current sync state synchronously
  SyncState get currentSyncState => _syncStateSubject.value;

  /// Check if offline storage is enabled
  bool get hasOfflineStorage => _client?.hasOfflineStorage ?? false;

  /// Get current notes synchronously
  List<Note> get currentNotes => _notesSubject.value;

  /// Get current folders synchronously
  List<Folder> get currentFolders => _foldersSubject.value;

  /// Get note update event stream with transaction context
  ///
  /// Use this to check isMyTransaction for distinguishing local echoes from remote changes
  Stream<stdb.TableUpdateEvent<Note>>? get noteUpdateEvents =>
      _client?.note.updateEventStream;

  /// Get note delete event stream with transaction context
  Stream<stdb.TableDeleteEvent<Note>>? get noteDeleteEvents =>
      _client?.note.deleteEventStream;

  void _emitCurrentNotes() {
    if (_client == null) return;

    try {
      final noteTable = _client!.note;
      final folderTable = _client!.folder;

      final notes = noteTable.iter().toList();
      final folders = folderTable.iter().toList();

      debugLogger.sync('Emitting ${notes.length} notes, ${folders.length} folders');

      notes
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      folders
          .sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      _notesSubject.add(notes);
      _foldersSubject.add(folders);
    } catch (e) {
      debugLogger.error('SYNC', 'Error emitting notes: $e');
      _notesSubject.addError(e);
      _foldersSubject.addError(e);
    }
  }

  Future<bool> isConfigured() async {
    final configured = _host != null && _host!.isNotEmpty;
    debugLogger.debug('REPO', 'isConfigured() = $configured');
    return configured;
  }

  /// Configure the repository with a new host.
  /// Database is always 'spacenotes'.
  /// Call [connectAndGetInitialData] after configuring to establish connection.
  Future<void> configure({required String host}) async {
    if (_client != null) {
      resetConnection();
    }

    _host = host;
    _database = 'spacenotes';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spacenotes_host', host);
    debugLogger.info('REPO', 'Configured: host=$host');
  }

  Future<bool> checkConnection() async {
    if (_client == null) {
      return false;
    }

    final isConnected =
        _client!.connection.status == stdb.ConnectionStatus.connected;
    return isConnected;
  }

  Future<Note?> getNote(String id) async {
    try {
      await _ensureConnected();

      if (_client == null) return null;

      // Find note by id (id is the primary key)
      final noteTable = _client!.note;
      final note = noteTable.find(id);

      return note;
    } catch (e) {
      debugLogger.error('REPO', 'Error loading note: $e');
      return null;
    }
  }

  Future<String?> createNote(String path, String content) async {
    debugLogger.save('Creating note: path=$path, len=${content.length}, hash=${_contentHash(content)}');
    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot create note');
        return null;
      }

      final existingNote = _client!.note.iter().firstWhereOrNull((n) => n.path == path);
      if (existingNote != null) {
        debugLogger.save('Note already exists at path: $path, returning existing ID');
        return existingNote.id;
      }

      final id = const Uuid().v4();

      final name = path.split('/').last.replaceAll('.md', '');

      final pathParts = path.split('/');
      final folderPath = pathParts.length > 1
          ? '${pathParts.sublist(0, pathParts.length - 1).join('/')}/'
          : '';

      final depth = folderPath.isEmpty
          ? 0
          : folderPath.split('/').where((s) => s.isNotEmpty).length;

      final now = DateTime.now().millisecondsSinceEpoch;

      final newNote = Note(
        id: id,
        path: path,
        name: name,
        content: content,
        folderPath: folderPath,
        depth: depth,
        frontmatter: '',
        size: Int64(content.length),
        createdTime: Int64(now),
        modifiedTime: Int64(now),
        dbUpdatedAt: Int64(0),
      );

      await _client!.reducers.createNote(
        id: id,
        path: path,
        name: name,
        content: content,
        folderPath: folderPath,
        depth: depth,
        frontmatter: '',
        size: Int64(content.length),
        createdTime: Int64(now),
        modifiedTime: Int64(now),
        optimisticChanges: [OptimisticChange.insert('note', newNote.toJson())],
      );

      debugLogger.save('Note created: $id');
      return id;
    } catch (e, stack) {
      debugLogger.error('SAVE', 'Error creating note: $e', stack.toString());
      return null;
    }
  }

  Future<bool> updateNote(String id, String content) async {
    try {
      await _ensureConnected();

      if (_client == null) return false;

      final oldNote = _client!.note.find(id);
      if (oldNote == null) return false;

      debugLogger.save('Sending update: id=${id.substring(0, 8)}, len=${content.length}, hash=${_contentHash(content)}');

      final now = DateTime.now().millisecondsSinceEpoch;

      final newNote = Note(
        id: oldNote.id,
        path: oldNote.path,
        name: oldNote.name,
        content: content,
        folderPath: oldNote.folderPath,
        depth: oldNote.depth,
        frontmatter: '',
        size: Int64(content.length),
        createdTime: oldNote.createdTime,
        modifiedTime: Int64(now),
        dbUpdatedAt: oldNote.dbUpdatedAt,
      );

      await _client!.reducers.updateNoteContent(
        id: id,
        content: content,
        frontmatter: '',
        size: Int64(content.length),
        modifiedTime: Int64(now),
        optimisticChanges: [
          OptimisticChange.update('note', oldNote.toJson(), newNote.toJson())
        ],
      );

      return true;
    } catch (e) {
      debugLogger.error('SAVE', 'Error updating note content: $e');
      return false;
    }
  }

  Future<bool> deleteNote(String id) async {
    debugLogger.save('deleteNote: $id');

    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot delete note');
        return false;
      }

      final oldNote = _client!.note.find(id);
      if (oldNote == null) {
        debugLogger.error('SAVE', 'Note not found in cache: $id');
        return false;
      }

      final optimisticPayload = oldNote.toJson();

      await _client!.reducers.deleteNote(
        id: id,
        optimisticChanges: [OptimisticChange.delete('note', optimisticPayload)],
      );

      debugLogger.save('Note deleted: $id');
      return true;
    } catch (e) {
      debugLogger.error('SAVE', 'Error deleting note: $e');
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

      final oldNote = _client!.note.find(id);
      if (oldNote == null) return false;

      final newName = newPath.split('/').last.replaceAll('.md', '');
      final pathParts = newPath.split('/');
      final newFolderPath = pathParts.length > 1
          ? '${pathParts.sublist(0, pathParts.length - 1).join('/')}/'
          : '';
      final newDepth = newFolderPath.isEmpty
          ? 0
          : newFolderPath.split('/').where((s) => s.isNotEmpty).length;

      final newNote = Note(
        id: oldNote.id,
        path: newPath,
        name: newName,
        content: oldNote.content,
        folderPath: newFolderPath,
        depth: newDepth,
        frontmatter: oldNote.frontmatter,
        size: oldNote.size,
        createdTime: oldNote.createdTime,
        modifiedTime: Int64(DateTime.now().millisecondsSinceEpoch),
        dbUpdatedAt: oldNote.dbUpdatedAt,
      );

      await _client!.reducers.renameNote(
        id: id,
        newPath: newPath,
        optimisticChanges: [
          OptimisticChange.update('note', oldNote.toJson(), newNote.toJson())
        ],
      );

      return true;
    } catch (e) {
      debugLogger.error('SAVE', 'Error renaming note: $e');
      return false;
    }
  }

  bool _generalNotesFolderEnsured = false;

  Future<void> ensureGeneralNotesFolder() async {
    if (_generalNotesFolderEnsured) return;

    try {
      if (_client == null) return;

      const generalNotesPath = 'All Notes';

      final folderTable = _client!.folder;
      final exists = folderTable.iter().any((f) => f.path == generalNotesPath);

      if (!exists) {
        debugLogger.info('FOLDER', 'Creating All Notes folder');
        await _client!.reducers.upsertFolder(
          path: generalNotesPath,
          name: 'All Notes',
          depth: 0,
        );
      }

      final noteTable = _client!.note;
      final rootNotes = noteTable
          .iter()
          .where((note) => note.folderPath.isEmpty || note.depth == 0)
          .toList();

      if (rootNotes.isNotEmpty) {
        debugLogger.info('FOLDER', 'Migrating ${rootNotes.length} root-level notes to All Notes');
        for (final note in rootNotes) {
          final newPath = 'All Notes/${note.path}';
          await _client!.reducers.moveNote(
            oldPath: note.path,
            newPath: newPath,
          );
        }
      }

      _generalNotesFolderEnsured = true;
    } catch (e) {
      debugLogger.error('FOLDER', 'Error ensuring All Notes folder: $e');
    }
  }

  Future<bool> patchNote({
    required String path,
    required String content,
    int? position,
    String? heading,
  }) async {
    debugLogger.warning('REPO', 'Patch note not supported in SpacetimeDB');
    return false;
  }

  /// Create a new folder
  Future<bool> createFolder(String path) async {
    debugLogger.info('FOLDER', 'createFolder: $path');

    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot create folder');
        return false;
      }

      final normalizedPath =
          path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      final name = normalizedPath.split('/').last;
      final depth = normalizedPath.split('/').length - 1;

      await _client!.reducers.upsertFolder(
        path: normalizedPath,
        name: name,
        depth: depth,
      );

      debugLogger.info('FOLDER', 'Created folder: $normalizedPath');
      return true;
    } catch (e) {
      debugLogger.error('FOLDER', 'Error creating folder: $e');
      return false;
    }
  }

  /// Delete a folder (will cascade delete all notes and subfolders)
  Future<bool> deleteFolder(String path) async {
    debugLogger.info('FOLDER', 'deleteFolder: $path');

    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot delete folder');
        return false;
      }

      final normalizedPath =
          path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      await _client!.reducers.deleteFolder(path: normalizedPath);

      debugLogger.info('FOLDER', 'Deleted folder: $normalizedPath');
      return true;
    } catch (e) {
      debugLogger.error('FOLDER', 'Error deleting folder: $e');
      return false;
    }
  }

  /// Move a folder to a new path (will cascade move all notes and subfolders)
  Future<bool> moveFolder(String oldPath, String newPath) async {
    debugLogger.info('FOLDER', 'moveFolder: $oldPath -> $newPath');

    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot move folder');
        return false;
      }

      final normalizedOldPath = oldPath.endsWith('/')
          ? oldPath.substring(0, oldPath.length - 1)
          : oldPath;
      final normalizedNewPath = newPath.endsWith('/')
          ? newPath.substring(0, newPath.length - 1)
          : newPath;

      await _client!.reducers.moveFolder(
        oldPath: normalizedOldPath,
        newPath: normalizedNewPath,
      );

      debugLogger.info('FOLDER', 'Moved folder: $normalizedOldPath -> $normalizedNewPath');
      return true;
    } catch (e) {
      debugLogger.error('FOLDER', 'Error moving folder: $e');
      return false;
    }
  }

  Future<bool> moveNote(String oldPath, String newPath) async {
    debugLogger.save('moveNote: $oldPath -> $newPath');

    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot move note');
        return false;
      }

      await _client!.reducers.moveNote(
        oldPath: oldPath,
        newPath: newPath,
      );

      debugLogger.save('Moved note: $oldPath -> $newPath');
      return true;
    } catch (e) {
      debugLogger.error('SAVE', 'Error moving note: $e');
      return false;
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    try {
      await _ensureConnected();

      if (_client == null) return [];

      // Get all notes and filter locally
      final noteTable = _client!.note;
      final notes = noteTable.iter().toList();

      final queryLower = query.toLowerCase();

      final matchingNotes = notes.where((note) {
        return note.name.toLowerCase().contains(queryLower) ||
            note.content.toLowerCase().contains(queryLower) ||
            note.path.toLowerCase().contains(queryLower);
      }).toList();

      return matchingNotes;
    } catch (e) {
      debugLogger.error('REPO', 'Error searching notes: $e');
      return [];
    }
  }

  /// Connect to SpacetimeDB and get initial data
  ///
  /// This ensures the client is connected, callbacks are registered,
  /// and emits the initial cache data to the stream
  Future<void> connectAndGetInitialData() async {
    debugLogger.connection('connectAndGetInitialData() called');
    await _ensureConnected();
    _emitCurrentNotes();
  }

  /// Try to reconnect if currently disconnected or in slow reconnect backoff
  ///
  /// Call this when network becomes available (e.g., app resume, connectivity change)
  /// This will cancel any pending backoff and attempt immediate reconnection
  /// If the first attempt fails, retries after a short delay
  Future<void> tryReconnect() async {
    if (_client == null) return;

    final status = _client!.connection.status;
    if (status == stdb.ConnectionStatus.connected ||
        status == stdb.ConnectionStatus.connecting) {
      return;
    }

    debugLogger.connection('Attempting to reconnect...');
    try {
      await _client!.connection.reconnect();
    } on SpacetimeDbAuthException {
      debugLogger.warning('AUTH', 'Auth expired during reconnect, clearing token');
      final storage = _authStorage ?? SharedPreferencesTokenStore();
      await storage.clearToken();
      await _client!.connection.reconnect();
      debugLogger.connection('Reconnected with fresh identity');
    } catch (e) {
      debugLogger.warning('CONN', 'Reconnection failed: $e, retrying in 2s');
      Future.delayed(const Duration(seconds: 2), () {
        if (_client != null &&
            _client!.connection.status == stdb.ConnectionStatus.disconnected) {
          tryReconnect();
        }
      });
    }
  }

  /// Update configuration when connecting to a new instance
  void updateConfiguration({
    required String host,
    String? database,
    stdb.AuthTokenStore? authStorage,
  }) {
    debugLogger.info('REPO', 'updateConfiguration: host=$host, db=$database');

    _host = host;
    _database = database;
    _authStorage = authStorage;

    resetConnection();
  }

  /// Reset the repository connection (used when switching instances)
  void resetConnection() {
    debugLogger.connection('Resetting connection');

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (_client != null) {
      try {
        _client!.disconnect();
      } catch (e) {
        debugLogger.error('CONN', 'Error disconnecting client: $e');
      }
      _client = null;
      _clientSubject.add(null);
    }

    _connectingFuture = null;
    _generalNotesFolderEnsured = false;
    _streamListenersRegistered = false;
    _initialSyncComplete = false;
  }

  /// Get the current client (for connection state monitoring)
  SpacetimeDbClient? get client => _client;

  /// Get current configuration
  String? get host => _host;
  String? get database => _database;
  stdb.AuthTokenStore? get authStorage => _authStorage;

  /// Dispose resources
  Future<void> dispose() async {
    debugLogger.info('REPO', 'Disposing repository');
    resetConnection();
    _notesSubject.close();
    _foldersSubject.close();
    _clientSubject.close();
    _syncStateSubject.close();
    await _offlineStorage?.dispose();
    _offlineStorage = null;
  }
}
