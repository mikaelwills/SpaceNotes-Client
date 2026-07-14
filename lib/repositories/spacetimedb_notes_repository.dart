import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart' as stdb;
import '../services/debug_logger.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart'
    show
        ConnectionConfig,
        Int64,
        OfflineStorage,
        JsonFileStorage,
        InMemoryOfflineStorage,
        SyncState,
        OptimisticChange,
        SpacetimeDbException,
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
  SpacetimeDbClient? _client;
  Future<void>? _connectingFuture;
  bool _retryScheduled = false;
  int _retryAttempt = 0;
  int _authErrorAttempts = 0;
  bool _nonTableListenersRegistered = false;
  bool _generalNotesFolderEnsured = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _lastConnectivityOnline = true;

  final ValueNotifier<SpacetimeDbClient?> clientNotifier =
      ValueNotifier<SpacetimeDbClient?>(null);

  final _syncStateSubject =
      BehaviorSubject<SyncState>.seeded(const SyncState());

  final List<StreamSubscription> _subscriptions = [];

  // Cold-start set: light/global tables only. The four per-session chat tables
  // (message, tool_event, permission_request, question_request) are subscribed
  // dynamically, scoped `WHERE session_id = <id>`, while a session screen is
  // open — see subscribeSession/unsubscribeSession.
  static const _initialSubscriptions = [
    'SELECT * FROM note',
    'SELECT * FROM folder',
    'SELECT * FROM call_session',
    'SELECT * FROM connected_user',
    'SELECT * FROM video_frame',
    'SELECT * FROM audio_frame',
    'SELECT * FROM session',
    'SELECT * FROM session_activity',
  ];

  static const _perSessionChatTables = [
    'message',
    'tool_event',
    'permission_request',
    'question_request',
  ];

  /// Subscribe the four per-session chat tables scoped to one session. Returns
  /// the SDK querySetId to pass back to [unsubscribeSession]. Awaits
  /// SubscribeApplied so the session's rows are in the cache on resolve.
  Future<int?> subscribeSession(String sessionId) async {
    final client = _client;
    if (client == null) {
      debugLogger.warning('SUB', 'subscribeSession: client null');
      return null;
    }
    final queries = _perSessionChatTables
        .map((t) => "SELECT * FROM $t WHERE session_id = '$sessionId'")
        .toList();
    return client.subscriptions.subscribe(queries);
  }

  void unsubscribeSession(int querySetId) {
    _client?.subscriptions.unsubscribe(querySetId);
  }

  static const _connectionConfig = ConnectionConfig(
    pingInterval: Duration(seconds: 15),
    pongTimeout: Duration(seconds: 10),
    autoReconnect: true,
    connectTimeout: Duration(seconds: 15),
    baseReconnectDelay: Duration(seconds: 10),
    maxReconnectDelay: Duration(seconds: 10),
    maxReconnectAttempts: 500,
  );

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

  /// Watch sync state for offline mutation status
  Stream<SyncState> watchSyncState() {
    return _syncStateSubject.stream;
  }

  /// Get current sync state synchronously
  SyncState get currentSyncState => _syncStateSubject.value;

  /// Check if offline storage is enabled
  bool get hasOfflineStorage => _client?.hasOfflineStorage ?? false;

  /// Dismiss the retained sync failures shown in the UI. Clears the
  /// `failedCount` / `recentFailures` carried on [SyncState] without
  /// touching the pending queue.
  void clearSyncErrors() {
    _client?.clearSyncErrors();
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

    return _client!.connection.state.isConnected;
  }

  Future<Note?> getNote(String id) async {
    try {
      await _ensureConnected();

      if (_client == null) return null;

      final noteTable = _client!.note;
      final note = noteTable.find(id);

      return note;
    } on SpacetimeDbException catch (e) {
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

      return true;
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
      debugLogger.error('SAVE', 'Error renaming note: $e');
      return false;
    }
  }

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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
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
    } on SpacetimeDbException catch (e) {
      debugLogger.error('REPO', 'Error searching notes: $e');
      return [];
    }
  }

  /// Connect to SpacetimeDB
  Future<void> connectAndGetInitialData() async {
    debugLogger.connection('connectAndGetInitialData() called');
    _startConnectivityWatch();
    await _ensureConnected();
  }

  /// Try to reconnect if currently disconnected or in slow reconnect backoff
  Future<void> tryReconnect({bool resetAttempts = false}) async {
    debugLogger.connection('tryReconnect() called');
    if (resetAttempts) _retryAttempt = 0;
    if (_client == null) {
      debugLogger.connection('tryReconnect: _client is null, returning');
      return;
    }

    final state = _client!.connection.state;
    debugLogger.connection('tryReconnect: state=${state.displayName}');

    if (state.isConnecting) {
      debugLogger.connection('tryReconnect: already connecting, returning');
      return;
    }

    if (_retryScheduled) {
      debugLogger.connection('tryReconnect: retry already scheduled, returning');
      return;
    }

    if (state.isConnected) {
      // State says connected but iOS/Android may have silently killed the
      // socket's read-half while backgrounded. Force a round-trip probe;
      // if the server doesn't answer within the timeout, fall through to
      // reconnect.
      debugLogger.connection('tryReconnect: running checkHealth (timeout=2s)');
      bool healthy;
      try {
        healthy = await _client!.subscriptions
            .checkHealth(timeout: const Duration(seconds: 2));
      } catch (e, st) {
        debugLogger.error(
          'CONN',
          'tryReconnect: checkHealth threw',
          '$e\n$st',
        );
        healthy = false;
      }
      debugLogger.connection('tryReconnect: checkHealth=$healthy');
      if (healthy) {
        debugLogger.connection('checkHealth ok, skipping reconnect');
        _retryAttempt = 0;
        return;
      }
      debugLogger.warning(
        'CONN',
        'checkHealth failed, connection is silently dead - reconnecting',
      );
    }

    debugLogger.connection('Attempting to reconnect...');
    try {
      await _client!.connection.reconnect();
      debugLogger.connection(
        'tryReconnect: reconnect() completed, state=${_client!.connection.state.displayName}',
      );
      if (_client!.connection.state.isConnected) {
        _retryAttempt = 0;
      } else {
        _scheduleRetry('reconnect completed but still disconnected');
      }
    } on SpacetimeDbAuthException {
      debugLogger.warning(
          'AUTH', 'Auth expired during reconnect, clearing token');
      final storage = _authStorage ?? SharedPreferencesTokenStore();
      await storage.clearToken();
      try {
        await _client!.connection.reconnect();
        debugLogger.connection('Reconnected with fresh identity');
        _retryAttempt = 0;
      } catch (_) {
        debugLogger.warning('AUTH',
            'In-place auth recovery failed - full rebuild for fresh identity');
        await _handleAuthError();
      }
    } on SpacetimeDbException catch (e) {
      _scheduleRetry(e.toString());
    } catch (e, st) {
      debugLogger.error(
        'CONN',
        'tryReconnect: reconnect() threw unexpected exception',
        '$e\n$st',
      );
      _scheduleRetry(e.toString());
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
      } on SpacetimeDbException catch (e) {
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

  /// Watch OS-level network connectivity. When the device transitions from
  /// offline to online, kick a reconnect immediately — this covers the
  /// cold-launched-while-offline case where the SDK never had a live socket
  /// to auto-reconnect, so nothing else would trigger recovery until the app
  /// was next resumed.
  void _startConnectivityWatch() {
    if (_connectivitySub != null) return;
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final cameOnline = online && !_lastConnectivityOnline;
      _lastConnectivityOnline = online;
      debugLogger.connection(
          'connectivity changed: online=$online, cameOnline=$cameOnline');
      if (cameOnline) {
        debugLogger.connection('Network restored - triggering reconnect');
        tryReconnect(resetAttempts: true);
      }
    });
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
            'CONN', 'Auth error - reconnecting in place');
        await tryReconnect();
        return;
      }

      if (state is stdb.Disconnected) {
        debugLogger.connection(
            '_ensureConnected Disconnected: hasOfflineStorage=${_client!.hasOfflineStorage}');
        if (_client!.hasOfflineStorage) {
          debugLogger.connection('Offline mode: using existing client');
          return;
        }
        debugLogger.warning(
            'CONN', 'DEGRADED CONNECTION: ${state.displayName} - reconnecting in place');
        await tryReconnect();
        return;
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
    _registerNonTableListeners();

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
    } on SpacetimeDbException catch (e) {
      debugLogger.error(
          'CONN', 'Error connecting to SpacetimeDB', e.toString());
      if (_client != null) {
        debugLogger.warning('CONN',
            'Initial connect failed offline - arming retry ladder to recover autonomously');
        _scheduleRetry('initial connect failed: $e');
        return;
      }
      rethrow;
    }
  }

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
      debugLogger.connection('state -> ${state.displayName}');
      if (state is stdb.Connected) {
        _authErrorAttempts = 0;
        return;
      }
      if (state is stdb.AuthError) {
        _handleAuthErrorGated();
        return;
      }
      if (state is stdb.FatalError) {
        debugLogger.warning('CONN',
            'Fatal error - re-arming repo retry to recover when server returns');
        _scheduleRetry('fatal error - re-arming');
      }
    });
    _subscriptions.add(connectionStateSub);

    debugLogger.sync('Non-table listeners registered');
  }

  Future<void> _handleAuthErrorGated() async {
    _authErrorAttempts++;
    if (_authErrorAttempts >= 2) {
      debugLogger.warning('AUTH',
          'AuthError persisted ($_authErrorAttempts) - full rebuild with fresh identity');
      await _handleAuthError();
      return;
    }
    debugLogger.warning('AUTH',
        'AuthError ($_authErrorAttempts) - reconnecting in place before rebuild');
    try {
      await tryReconnect();
    } catch (_) {}
  }

  Future<void> _handleAuthError() async {
    final storage = _authStorage ?? SharedPreferencesTokenStore();
    await storage.clearToken();
    resetConnection();
    await connectAndGetInitialData();
  }

  /// Schedule the next reconnect attempt. Fixed 10s interval, up to
  /// [_maxRetryAttempts] (~83 min of trying) — SpaceNotes reconnects
  /// aggressively whether the drop was from a live connection or a failed
  /// cold start. The loop stops once connected (checked at the top of
  /// [tryReconnect]) or once the cap is hit.
  static const _retryInterval = Duration(seconds: 10);
  static const _maxRetryAttempts = 500;

  void _scheduleRetry(String reason) {
    if (_retryScheduled) return;
    if (_retryAttempt >= _maxRetryAttempts) {
      debugLogger.warning('CONN',
          'Reconnect cap ($_maxRetryAttempts) reached - stopping retry loop until next resume/connectivity event');
      return;
    }
    _retryAttempt += 1;
    _retryScheduled = true;
    debugLogger.warning(
      'CONN',
      'Reconnection failed: $reason, retrying in ${_retryInterval.inSeconds}s (attempt $_retryAttempt/$_maxRetryAttempts)',
    );
    Future.delayed(_retryInterval, () {
      _retryScheduled = false;
      if (_client == null) return;
      if (_client!.connection.state.isConnected) {
        _retryAttempt = 0;
        return;
      }
      tryReconnect();
    });
  }
}
