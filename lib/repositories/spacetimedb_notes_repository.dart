import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../services/debug_logger.dart';
import '../services/title_generation_service.dart';
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
import 'shared_preferences_token_store.dart';
import 'package:rxdart/rxdart.dart';

String _contentHash(String content) {
  final bytes = utf8.encode(content);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}

/// Notes repository implementation using SpacetimeDB
class SpacetimeDbNotesRepository {
  String? _host;
  String? _database;
  stdb.AuthTokenStore? _authStorage;
  OfflineStorage? _offlineStorage;
  TitleGenerationService? _titleService;
  TitleGenerationService? get titleService => _titleService;

  void setTitleService(TitleGenerationService service) {
    _titleService = service;
  }

  SpacetimeDbClient? _client;
  Future<void>? _connectingFuture;

  final ValueNotifier<SpacetimeDbClient?> clientNotifier =
      ValueNotifier<SpacetimeDbClient?>(null);

  final _syncStateSubject =
      BehaviorSubject<SyncState>.seeded(const SyncState());

  final List<StreamSubscription> _subscriptions = [];

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

  Future<void> _ensureConnected() async {
    if (_client != null) {
      final state = _client!.connection.state;
      debugLogger.connection(
          '_ensureConnected: client exists, state=${state.displayName}');

      if (state.isConnected) {
        return;
      }

      if (state.isConnecting) {
        debugLogger.connection(
            'In progress (${state.displayName}), client available for offline ops');
        return;
      }

      if (state is stdb.AuthError) {
        debugLogger.warning(
            'CONN', 'Auth error - will clear token on reconnect');
        resetConnection();
      }

      if (state is stdb.Disconnected) {
        if (_client!.hasOfflineStorage) {
          debugLogger.connection('Offline mode: using existing client');
          return;
        }
        debugLogger.warning(
            'CONN', 'DEGRADED CONNECTION: ${state.displayName}');
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
      debugLogger.info(
          'STORAGE', 'Web platform - using InMemoryOfflineStorage');
      return InMemoryOfflineStorage();
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final storagePath = '${appDir.path}/spacenotes_offline';
      debugLogger.info(
          'STORAGE', 'Native platform - using JsonFileStorage', storagePath);
      final storage = JsonFileStorage(basePath: storagePath);
      await storage.initialize();
      return storage;
    } catch (e) {
      debugLogger.error(
          'STORAGE', 'Failed to create offline storage', e.toString());
      return null;
    }
  }

  static const _initialSubscriptions = [
    'SELECT * FROM note',
    'SELECT * FROM folder',
    'SELECT * FROM call_session',
    'SELECT * FROM connected_user',
    'SELECT * FROM video_frame',
    'SELECT * FROM audio_frame',
  ];

  static const _connectionConfig = ConnectionConfig(
    pingInterval: Duration(seconds: 4),
    pongTimeout: Duration(seconds: 5),
    autoReconnect: true,
    connectTimeout: Duration(seconds: 5),
  );

  Future<SpacetimeDbClient> _createAndConnectClient(
    stdb.AuthTokenStore storage,
  ) async {
    final client = await SpacetimeDbClient.create(
      host: _host!,
      database: _database!,
      authStorage: storage,
      offlineStorage: _offlineStorage,
      ssl: false,
      config: _connectionConfig,
    );

    _client = client;
    clientNotifier.value = client;

    await client.connect(
      initialSubscriptions: _initialSubscriptions,
      subscriptionTimeout: const Duration(seconds: 10),
    );

    return client;
  }

  Future<void> _connect() async {
    try {
      debugLogger.connection(
          'Connecting to SpacetimeDB', 'host=$_host, db=$_database');

      final storage = _authStorage ?? SharedPreferencesTokenStore();

      _offlineStorage ??= await _createOfflineStorage();

      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await _createAndConnectClient(storage);
          break;
        } on SpacetimeDbAuthException {
          debugLogger.warning(
              'AUTH', 'Auth failure (401) - clearing token and retrying');
          await storage.clearToken();
          await _createAndConnectClient(storage);
          debugLogger.connection('Reconnected with fresh anonymous identity');
          break;
        } catch (e) {
          if (attempt < maxRetries) {
            debugLogger.warning('CONN',
                'Attempt $attempt failed: $e, retrying in ${retryDelay.inSeconds}s');
            await Future.delayed(retryDelay);
          } else {
            rethrow;
          }
        }
      }

      final isConnected = _client!.connection.state.isConnected;
      if (isConnected) {
        debugLogger.connection('Successfully connected to SpacetimeDB');
      } else {
        debugLogger
            .connection('Operating in offline mode (cached data available)');
      }

      _registerNonTableListeners();

      if (isConnected) {
        await ensureGeneralNotesFolder();
      }
    } catch (e) {
      debugLogger.error(
          'CONN', 'Error connecting to SpacetimeDB', e.toString());
      rethrow;
    }
  }

  bool _nonTableListenersRegistered = false;

  /// Listeners that are not watchable via the per-table ValueNotifier API.
  /// Table row/event watching happens directly in providers via `client.note.rows`
  /// and `client.note.lastBatch`.
  void _registerNonTableListeners() {
    if (_client == null) return;
    if (_nonTableListenersRegistered) return;
    _nonTableListenersRegistered = true;

    if (_client!.hasOfflineStorage) {
      final syncStateSub = _client!.onSyncStateChanged.listen((state) {
        debugLogger.debug(
          'SYNC_SDK',
          'SDK sync state changed: isSyncing=${state.isSyncing}, pending=${state.pendingCount}, hasError=${state.hasError}',
        );
        _syncStateSubject.add(state);
      });
      _subscriptions.add(syncStateSub);
      final initialState = _client!.syncState;
      _syncStateSubject.add(initialState);
    }

    final connectionStateSub =
        _client!.connection.onStateChanged.listen((state) {
      if (state is stdb.AuthError) {
        debugLogger.warning('AUTH',
            'Auth error detected - auto-clearing token and reconnecting');
        _handleAuthError();
      }
    });
    _subscriptions.add(connectionStateSub);

    debugLogger.sync('Non-table listeners registered');
  }

  Future<void> _handleAuthError() async {
    final storage = _authStorage ?? SharedPreferencesTokenStore();
    await storage.clearToken();
    resetConnection();
    await connectAndGetInitialData();
  }

  /// Watch sync state for offline mutation status
  Stream<SyncState> watchSyncState() {
    return _syncStateSubject.stream;
  }

  /// Get current sync state synchronously
  SyncState get currentSyncState => _syncStateSubject.value;

  /// Check if offline storage is enabled
  bool get hasOfflineStorage => _client?.hasOfflineStorage ?? false;

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

    return _client!.connection.state.isConnected;
  }

  Future<Note?> getNote(String id) async {
    try {
      await _ensureConnected();

      if (_client == null) return null;

      final noteTable = _client!.note;
      final note = noteTable.find(id);

      return note;
    } catch (e) {
      debugLogger.error('REPO', 'Error loading note: $e');
      return null;
    }
  }

  Future<String?> createNote(String path, String content) async {
    debugLogger.save(
        'Creating note: path=$path, len=${content.length}, hash=${_contentHash(content)}');
    try {
      await _ensureConnected();

      if (_client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot create note');
        return null;
      }

      final existingNote =
          _client!.note.iter().firstWhereOrNull((n) => n.path == path);
      if (existingNote != null) {
        debugLogger
            .save('Note already exists at path: $path, returning existing ID');
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

      debugLogger.save(
          'Sending update: id=${id.substring(0, 8)}, len=${content.length}, hash=${_contentHash(content)}');

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

      _titleService?.onNoteSaved(id, content, oldNote.path);

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
        debugLogger.info('FOLDER',
            'Migrating ${rootNotes.length} root-level notes to All Notes');
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

      debugLogger.info(
          'FOLDER', 'Moved folder: $normalizedOldPath -> $normalizedNewPath');
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

  /// Connect to SpacetimeDB
  Future<void> connectAndGetInitialData() async {
    debugLogger.connection('connectAndGetInitialData() called');
    await _ensureConnected();
  }

  /// Try to reconnect if currently disconnected or in slow reconnect backoff
  Future<void> tryReconnect() async {
    if (_client == null) return;

    final state = _client!.connection.state;
    if (state.isConnected || state.isConnecting) {
      return;
    }

    debugLogger.connection('Attempting to reconnect...');
    try {
      await _client!.connection.reconnect();
    } on SpacetimeDbAuthException {
      debugLogger.warning(
          'AUTH', 'Auth expired during reconnect, clearing token');
      final storage = _authStorage ?? SharedPreferencesTokenStore();
      await storage.clearToken();
      await _client!.connection.reconnect();
      debugLogger.connection('Reconnected with fresh identity');
    } catch (e) {
      debugLogger.warning('CONN', 'Reconnection failed: $e, retrying in 2s');
      Future.delayed(const Duration(seconds: 2), () {
        if (_client != null) {
          final retryState = _client!.connection.state;
          if (retryState.canRetry) {
            tryReconnect();
          }
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
      clientNotifier.value = null;
    }

    _connectingFuture = null;
    _generalNotesFolderEnsured = false;
    _nonTableListenersRegistered = false;
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
    clientNotifier.dispose();
    _syncStateSubject.close();
    await _offlineStorage?.dispose();
    _offlineStorage = null;
  }
}
