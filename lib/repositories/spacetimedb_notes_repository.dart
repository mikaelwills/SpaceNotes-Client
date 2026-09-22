import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, ValueListenable, ValueNotifier, visibleForTesting;
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
import '../generated/file_content.dart';
import '../generated/space_file.dart';
import 'shared_preferences_token_store.dart';
import 'package:rxdart/rxdart.dart';
import '../file_types/file_type_registry.dart';

String _contentHash(String content) {
  final bytes = utf8.encode(content);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}

String _extensionOf(String path) {
  final basename = path.split('/').last;
  final dotIndex = basename.lastIndexOf('.');
  if (dotIndex < 0) return '';
  return basename.substring(dotIndex + 1).toLowerCase();
}

class CredentialWriteRefused implements Exception {
  const CredentialWriteRefused(this.message, {this.collidingPath});

  final String message;
  final String? collidingPath;

  @override
  String toString() => 'CredentialWriteRefused: $message';
}

String folderPathOf(String path) {
  final parts = path.split('/');
  if (parts.length <= 1) return '';
  return '${parts.sublist(0, parts.length - 1).join('/')}/';
}

int folderDepthOf(String folderPath) =>
    folderPath.split('/').where((s) => s.isNotEmpty).length;

String? findCollidingPath({
  required String path,
  required Iterable<String> existingPaths,
  String? ignoreExactPath,
}) {
  final target = path.toLowerCase();
  for (final existing in existingPaths) {
    if (ignoreExactPath != null && existing == ignoreExactPath) continue;
    if (existing.toLowerCase() == target) return existing;
  }
  return null;
}

/// Per-connection state for one lane (one [SpacetimeDbClient], one socket).
///
/// Everything here is state that a single client owns and that a second client
/// must not share: the client itself, its offline cache, its hydration span,
/// its query-set bookkeeping and its own rung on the reconnect ladder. Shared
/// configuration (host, database, auth store) stays on the repository.
class _ClientLane {
  _ClientLane({
    required this.name,
    required this.storageSuffix,
    required this.initialSubscriptions,
  });

  final String name;
  final String storageSuffix;
  final List<String> initialSubscriptions;

  SpacetimeDbClient? client;
  OfflineStorage? offlineStorage;
  bool nonTableListenersRegistered = false;
  LogSpan? hydrationSpan;
  int hydrationWireBytes = 0;
  final Set<LogSpan> contentSpans = {};
  int connectAttempts = 0;
  bool retryScheduled = false;
  int retryAttempt = 0;
  bool hasEverConnected = false;
  bool initialConnectAttempted = false;

  final ValueNotifier<SpacetimeDbClient?> clientNotifier =
      ValueNotifier<SpacetimeDbClient?>(null);
  final ValueNotifier<Set<int>> appliedQuerySets =
      ValueNotifier<Set<int>>(const {});
  final Map<int, SpacetimeDbClient> querySetOwners = {};
  final Set<int> deferredUnsubscribes = {};
  final List<StreamSubscription> subscriptions = [];

  String tag(String message) => '[$name] $message';

  void markApplied(int querySetId) {
    if (appliedQuerySets.value.contains(querySetId)) return;
    appliedQuerySets.value = {...appliedQuerySets.value, querySetId};
  }

  void forgetApplied(int querySetId) {
    if (!appliedQuerySets.value.contains(querySetId)) return;
    appliedQuerySets.value = {...appliedQuerySets.value}..remove(querySetId);
  }
}

/// Notes repository implementation using SpacetimeDB
class SpacetimeDbNotesRepository {
  String? _host;
  String? _database;
  stdb.AuthTokenStore? _authStorage;
  Future<void>? _connectingFuture;
  Future<void>? _staleTokenRecovery;
  int _authErrorAttempts = 0;
  bool _generalNotesFolderEnsured = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _lastConnectivityOnline = true;

  final _ClientLane _notesLane = _ClientLane(
    name: 'notes',
    storageSuffix: '_notes',
    initialSubscriptions: _notesInitialSubscriptions,
  );

  final _ClientLane _chatLane = _ClientLane(
    name: 'chat',
    storageSuffix: '_chat',
    initialSubscriptions: _chatInitialSubscriptions,
  );

  late final List<_ClientLane> _lanes = [_notesLane, _chatLane];

  ValueNotifier<SpacetimeDbClient?> get clientNotifier =>
      _notesLane.clientNotifier;

  ValueNotifier<SpacetimeDbClient?> get notesClientNotifier =>
      _notesLane.clientNotifier;

  ValueNotifier<SpacetimeDbClient?> get chatClientNotifier =>
      _chatLane.clientNotifier;

  ValueListenable<Set<int>> get appliedNotesQuerySets =>
      _notesLane.appliedQuerySets;

  final _syncStateSubject =
      BehaviorSubject<SyncState>.seeded(const SyncState());

  static const _notesInitialSubscriptions = [
    'SELECT * FROM space_file',
    'SELECT * FROM folder',
  ];

  // Cold-start set: light/global tables only. The four per-agent chat tables
  // (message, tool_event, permission_request, question_request) are subscribed
  // dynamically, scoped `WHERE agent_id = <id>`, while an agent screen is
  // open — see subscribeAgent/unsubscribeAgent.
  static const _chatInitialSubscriptions = [
    'SELECT * FROM agent',
    'SELECT * FROM channel_config',
    'SELECT * FROM agent_activity',
    'SELECT * FROM call_session',
    'SELECT * FROM connected_user',
    'SELECT * FROM video_frame',
    'SELECT * FROM audio_frame',
  ];

  static const _perAgentChatTables = [
    'message',
    'tool_event',
    'permission_request',
    'question_request',
  ];

  /// Subscribe the four per-agent chat tables scoped to one agent. Returns
  /// the SDK querySetId to pass back to [unsubscribeAgent]. Awaits
  /// SubscribeApplied so the agent's rows are in the cache on resolve.
  Future<int?> subscribeAgent(String agentId) async {
    final client = _chatLane.client;
    if (client == null) {
      debugLogger.warning('SUB', _chatLane.tag('subscribeAgent: client null'));
      return null;
    }
    final queries = _perAgentChatTables
        .map((t) => "SELECT * FROM $t WHERE agent_id = '$agentId'")
        .toList();
    final qsId = await client.subscriptions.subscribe(queries);
    _chatLane.querySetOwners[qsId] = client;
    return qsId;
  }

  void unsubscribeAgent(int querySetId) {
    final owner = _chatLane.querySetOwners.remove(querySetId);
    _chatLane.forgetApplied(querySetId);
    final client = _chatLane.client;
    if (client == null || !identical(owner, client)) return;
    if (!client.connection.state.isConnected) {
      _chatLane.deferredUnsubscribes.add(querySetId);
      client.subscriptions.forgetQuerySet(querySetId);
      return;
    }
    client.subscriptions.unsubscribe(querySetId);
  }

  /// Subscribe one file's body row. `file_content` is deliberately absent
  /// from the cold-start set: bodies are only streamed while a note is open,
  /// so listing files never pays for downloading every body. Returns the SDK
  /// querySetId to pass back to [unsubscribeFileContent]. Awaits
  /// SubscribeApplied so the row is in the cache on resolve. A file with no
  /// `file_content` row (large binaries) resolves normally with nothing in
  /// cache — that is empty content, not an error. The SDK also resolves when
  /// the connection drops before SubscribeApplied; check the returned id
  /// against [appliedNotesQuerySets] to tell the two apart.
  Future<int?> subscribeFileContent(String fileId) async {
    final client = _notesLane.client;
    if (client == null) {
      debugLogger.warning(
          'SUB', _notesLane.tag('subscribeFileContent: client null'));
      return null;
    }
    final span = debugLogger.span(
        'HYDRATION', _notesLane.tag('note-content $fileId'));
    _notesLane.contentSpans.add(span);
    try {
      final qsId = await client.subscriptions.subscribe(
          ["SELECT * FROM file_content WHERE file_id = '$fileId'"]);
      _notesLane.querySetOwners[qsId] = client;
      if (!_notesLane.appliedQuerySets.value.contains(qsId)) {
        span.end('resolved without SubscribeApplied (connection dropped)');
        return qsId;
      }
      final row = client.fileContent.rows.value
          .firstWhereOrNull((r) => r.fileId == fileId);
      span.end(row == null
          ? 'applied, no file_content row'
          : 'applied chars=${row.content.length}');
      return qsId;
    } catch (e) {
      span.end('aborted: $e');
      rethrow;
    } finally {
      _notesLane.contentSpans.remove(span);
    }
  }

  void unsubscribeFileContent(int querySetId) {
    final owner = _notesLane.querySetOwners.remove(querySetId);
    _notesLane.forgetApplied(querySetId);
    final client = _notesLane.client;
    if (client == null || !identical(owner, client)) return;
    if (!client.connection.state.isConnected) {
      _notesLane.deferredUnsubscribes.add(querySetId);
      client.subscriptions.forgetQuerySet(querySetId);
      return;
    }
    client.subscriptions.unsubscribe(querySetId);
  }

  /// Subscribe the four chat tables for several agents in ONE query set,
  /// so they stay warm in the offline cache (used for the recently-touched
  /// agents at connect). Uses the same proven `= id` scoped query shape as
  /// [subscribeAgent] — no dependency on IN-clause support. Awaits
  /// SubscribeApplied. Returns the querySetId, or null if there are no ids.
  Future<int?> subscribeAgents(List<String> agentIds) async {
    final client = _chatLane.client;
    if (client == null) {
      debugLogger.warning('SUB', _chatLane.tag('subscribeAgents: client null'));
      return null;
    }
    if (agentIds.isEmpty) return null;
    final queries = <String>[
      for (final id in agentIds)
        for (final t in _perAgentChatTables)
          "SELECT * FROM $t WHERE agent_id = '$id'",
    ];
    debugLogger.connection(_chatLane.tag(
        'subscribeAgents: warming ${agentIds.length} agents (${queries.length} queries)'));
    final qsId = await client.subscriptions.subscribe(queries);
    _chatLane.querySetOwners[qsId] = client;
    return qsId;
  }

  static const _connectionConfig = ConnectionConfig(
    pingInterval: Duration(seconds: 10),
    pongTimeout: Duration(seconds: 5),
    autoReconnect: true,
    appLevelKeepAlive: true,
    retryInitialConnect: true,
    connectTimeout: Duration(seconds: 8),
    baseReconnectDelay: Duration(seconds: 5),
    maxReconnectDelay: Duration(seconds: 45),
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
  bool get hasOfflineStorage => _notesLane.client?.hasOfflineStorage ?? false;

  /// Dismiss the retained sync failures shown in the UI. Clears the
  /// `failedCount` / `recentFailures` carried on [SyncState] without
  /// touching the pending queue.
  void clearSyncErrors() {
    _notesLane.client?.clearSyncErrors();
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
    if (_notesLane.client != null) {
      resetConnection();
    }

    _host = host;
    _database = 'spacenotes';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spacenotes_host', host);
    debugLogger.info('REPO', 'Configured: host=$host');
  }

  Future<bool> checkConnection() async {
    if (_notesLane.client == null) {
      return false;
    }

    return _notesLane.client!.connection.state.isConnected;
  }

  Future<SpaceFile?> getNote(String id) async {
    try {
      await _ensureConnected();

      if (_notesLane.client == null) return null;

      final noteTable = _notesLane.client!.spaceFile;
      final note = noteTable.find(id);

      return note;
    } on SpacetimeDbException catch (e) {
      debugLogger.error('REPO', 'Error loading note: $e');
      return null;
    }
  }

  Future<void> writeCredential({
    required String id,
    required String path,
    required String content,
    String? replacingPath,
  }) async {
    await _ensureConnected();

    if (_notesLane.client == null) {
      throw const CredentialWriteRefused(
        'not connected, so the credential was not written',
      );
    }

    final collision = findCollidingPath(
      path: path,
      existingPaths: _notesLane.client!.spaceFile.iter().map((f) => f.path),
      ignoreExactPath: replacingPath ?? path,
    );
    if (collision != null) {
      throw CredentialWriteRefused(
        'an entry already exists at $collision, so nothing was written',
        collidingPath: collision,
      );
    }

    final fileName = path.split('/').last;
    final name = FileTypeRegistry.forFileName(fileName).stripExtension(fileName);

    final folderPath = folderPathOf(path);
    final depth = folderDepthOf(folderPath);

    final existing = _notesLane.client!.spaceFile.find(id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final decodedSize = base64Decode(content).length;

    try {
      await _notesLane.client!.reducers.upsertFile(
        id: id,
        path: path,
        name: name,
        content: content,
        folderPath: folderPath,
        depth: depth,
        extension: _extensionOf(path),
        size: Int64(decodedSize),
        createdTime: Int64(existing?.createdTime.toInt() ?? now),
        modifiedTime: Int64(now),
      );
    } on SpacetimeDbException catch (e) {
      throw CredentialWriteRefused(
        'the vault refused the write for $path, most likely because another '
        'device already holds that name: $e',
      );
    }
  }

  Future<String?> createNote(String path, String content) async {
    debugLogger.save(
        'Creating note: path=$path, len=${content.length}, hash=${_contentHash(content)}');
    try {
      await _ensureConnected();

      if (_notesLane.client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot create note');
        return null;
      }

      final existingNote =
          _notesLane.client!.spaceFile.iter().firstWhereOrNull((n) => n.path == path);
      if (existingNote != null) {
        debugLogger
            .save('Note already exists at path: $path, returning existing ID');
        return existingNote.id;
      }

      final id = const Uuid().v4();

      final fileName = path.split('/').last;
      final name = FileTypeRegistry.forFileName(fileName).stripExtension(fileName);

      final pathParts = path.split('/');
      final folderPath = pathParts.length > 1
          ? '${pathParts.sublist(0, pathParts.length - 1).join('/')}/'
          : '';

      final depth = folderPath.isEmpty
          ? 0
          : folderPath.split('/').where((s) => s.isNotEmpty).length;

      final now = DateTime.now().millisecondsSinceEpoch;

      final extension = _extensionOf(path);

      final newNote = SpaceFile(
        id: id,
        path: path,
        name: name,
        folderPath: folderPath,
        depth: depth,
        extension: extension,
        size: Int64(content.length),
        createdTime: Int64(now),
        modifiedTime: Int64(now),
        dbUpdatedAt: Int64(0),
        hasThumbnail: false,
      );

      await _notesLane.client!.reducers.createFile(
        id: id,
        path: path,
        name: name,
        content: content,
        folderPath: folderPath,
        depth: depth,
        extension: extension,
        size: Int64(content.length),
        createdTime: Int64(now),
        modifiedTime: Int64(now),
        optimisticChanges: [
          OptimisticChange.insert('space_file', newNote.toJson()),
          OptimisticChange.insert(
            'file_content',
            FileContent(fileId: id, content: content).toJson(),
          ),
        ],
      );

      debugLogger.save('Note created: $id');
      return id;
    } on CredentialWriteRefused {
      rethrow;
    } catch (e, stack) {
      debugLogger.error('SAVE', 'Error creating note: $e', stack.toString());
      return null;
    }
  }

  /// Saves a note's body.
  ///
  /// Both the metadata row and the content row change optimistically. Without
  /// the content half the editor would show its own typing revert until the
  /// server echo arrived, because the body it renders now comes from
  /// `file_content` rather than from the file row.
  ///
  /// The content row may legitimately not exist yet — a large binary never has
  /// one — so this inserts rather than updates in that case.
  Future<bool> updateNote(String id, String content) async {
    try {
      await _ensureConnected();

      if (_notesLane.client == null) return false;

      final oldNote = _notesLane.client!.spaceFile.find(id);
      if (oldNote == null) return false;

      debugLogger.save(
          'Sending update: id=${id.substring(0, 8)}, len=${content.length}, hash=${_contentHash(content)}');

      final now = DateTime.now().millisecondsSinceEpoch;

      final newNote = SpaceFile(
        id: oldNote.id,
        path: oldNote.path,
        name: oldNote.name,
        folderPath: oldNote.folderPath,
        depth: oldNote.depth,
        extension: oldNote.extension,
        size: Int64(content.length),
        createdTime: oldNote.createdTime,
        modifiedTime: Int64(now),
        dbUpdatedAt: oldNote.dbUpdatedAt,
        hasThumbnail: oldNote.hasThumbnail,
      );

      final oldContent = _notesLane.client!.fileContent.find(id);
      final newContent = FileContent(fileId: id, content: content);

      await _notesLane.client!.reducers.updateFileContent(
        id: id,
        content: content,
        size: Int64(content.length),
        modifiedTime: Int64(now),
        optimisticChanges: [
          OptimisticChange.update('space_file', oldNote.toJson(), newNote.toJson()),
          if (oldContent == null)
            OptimisticChange.insert('file_content', newContent.toJson())
          else
            OptimisticChange.update(
              'file_content',
              oldContent.toJson(),
              newContent.toJson(),
            ),
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

      if (_notesLane.client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot delete note');
        return false;
      }

      final oldNote = _notesLane.client!.spaceFile.find(id);
      if (oldNote == null) {
        debugLogger.error('SAVE', 'Note not found in cache: $id');
        return false;
      }

      final optimisticPayload = oldNote.toJson();

      await _notesLane.client!.reducers.deleteFile(
        id: id,
        optimisticChanges: [OptimisticChange.delete('space_file', optimisticPayload)],
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

      if (_notesLane.client == null) {
        return false;
      }

      final oldNote = _notesLane.client!.spaceFile.find(id);
      if (oldNote == null) return false;

      final newFileName = newPath.split('/').last;
      final newName =
          FileTypeRegistry.forFileName(newFileName).stripExtension(newFileName);
      final pathParts = newPath.split('/');
      final newFolderPath = pathParts.length > 1
          ? '${pathParts.sublist(0, pathParts.length - 1).join('/')}/'
          : '';
      final newDepth = newFolderPath.isEmpty
          ? 0
          : newFolderPath.split('/').where((s) => s.isNotEmpty).length;

      final newExtension = _extensionOf(newPath);

      final newNote = SpaceFile(
        id: oldNote.id,
        path: newPath,
        name: newName,
        folderPath: newFolderPath,
        depth: newDepth,
        extension: newExtension,
        size: oldNote.size,
        createdTime: oldNote.createdTime,
        modifiedTime: Int64(DateTime.now().millisecondsSinceEpoch),
        dbUpdatedAt: oldNote.dbUpdatedAt,
        hasThumbnail: oldNote.hasThumbnail,
      );

      await _notesLane.client!.reducers.renameFile(
        id: id,
        newPath: newPath,
        optimisticChanges: [
          OptimisticChange.update('space_file', oldNote.toJson(), newNote.toJson())
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
      if (_notesLane.client == null) return;

      const generalNotesPath = 'All Notes';

      final folderTable = _notesLane.client!.folder;
      final exists = folderTable.iter().any((f) => f.path == generalNotesPath);

      if (!exists) {
        debugLogger.info('FOLDER', 'Creating All Notes folder');
        await _notesLane.client!.reducers.upsertFolder(
          path: generalNotesPath,
          name: 'All Notes',
          depth: 0,
        );
      }

      final noteTable = _notesLane.client!.spaceFile;
      final rootNotes = noteTable
          .iter()
          .where((note) => note.folderPath.isEmpty || note.depth == 0)
          .toList();

      if (rootNotes.isNotEmpty) {
        debugLogger.info('FOLDER',
            'Migrating ${rootNotes.length} root-level notes to All Notes');
        for (final note in rootNotes) {
          final newPath = 'All Notes/${note.path}';
          await _notesLane.client!.reducers.moveFile(
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

      if (_notesLane.client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot create folder');
        return false;
      }

      final normalizedPath =
          path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      final name = normalizedPath.split('/').last;
      final depth = normalizedPath.split('/').length - 1;

      await _notesLane.client!.reducers.upsertFolder(
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

      if (_notesLane.client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot delete folder');
        return false;
      }

      final normalizedPath =
          path.endsWith('/') ? path.substring(0, path.length - 1) : path;

      await _notesLane.client!.reducers.deleteFolder(path: normalizedPath);

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

      if (_notesLane.client == null) {
        debugLogger.error('FOLDER', 'Client is null, cannot move folder');
        return false;
      }

      final normalizedOldPath = oldPath.endsWith('/')
          ? oldPath.substring(0, oldPath.length - 1)
          : oldPath;
      final normalizedNewPath = newPath.endsWith('/')
          ? newPath.substring(0, newPath.length - 1)
          : newPath;

      await _notesLane.client!.reducers.moveFolder(
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

      if (_notesLane.client == null) {
        debugLogger.error('SAVE', 'Client is null, cannot move note');
        return false;
      }

      await _notesLane.client!.reducers.moveFile(
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

  Future<List<SpaceFile>> searchNotes(String query) async {
    try {
      await _ensureConnected();

      if (_notesLane.client == null) return [];

      final noteTable = _notesLane.client!.spaceFile;
      final notes = noteTable.iter().toList();

      final queryLower = query.toLowerCase();

      final matchingNotes = notes.where((note) {
        return note.name.toLowerCase().contains(queryLower) ||
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

  /// Try to reconnect if currently disconnected or in slow reconnect backoff.
  ///
  /// [force] treats a lingering [stdb.Reconnecting] state as stale and tears it
  /// down before reconnecting. Used by the resume path: while backgrounded the
  /// isolate is frozen, so a reconnect scheduled before backgrounding can't run
  /// and leaves a zombie `Reconnecting` that the `isConnecting` guard below
  /// would otherwise wait out (~10s). It deliberately does NOT bypass a live
  /// `Connecting`, so repeated manual reconnects still coalesce.
  Future<void> tryReconnect({
    bool resetAttempts = false,
    bool force = false,
  }) async {
    await Future.wait([
      for (final lane in _lanes)
        _tryReconnectLane(lane, resetAttempts: resetAttempts, force: force),
    ]);
  }

  /// Tear the connection down when the app is backgrounded. iOS/Android freeze
  /// the isolate on pause, so any in-flight reconnect timer stops mid-flight
  /// and the socket dies silently — leaving a zombie `Reconnecting` that the
  /// resume path then has to wait out. Disconnecting proactively means resume
  /// always starts from a clean `Disconnected`. Pending offline mutations live
  /// in persisted offline storage and are untouched by [disconnect].
  void pauseSpanClocks() {
    for (final lane in _lanes) {
      lane.hydrationSpan?.pause();
      for (final span in lane.contentSpans) {
        span.pause();
      }
    }
  }

  void resumeSpanClocks() {
    for (final lane in _lanes) {
      lane.hydrationSpan?.resume();
      for (final span in lane.contentSpans) {
        span.resume();
      }
    }
  }

  Future<void> handleAppPaused() async {
    await Future.wait([for (final lane in _lanes) _handleAppPausedLane(lane)]);
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

    for (final lane in _lanes) {
      lane.hasEverConnected = false;
      lane.initialConnectAttempted = false;
      _resetLane(lane);
    }

    _connectingFuture = null;
    _generalNotesFolderEnsured = false;
  }

  /// The notes-domain client — files and folders.
  SpacetimeDbClient? get notesClient => _notesLane.client;

  /// The chat-domain client — agents, messages, calls and presence.
  SpacetimeDbClient? get chatClient => _chatLane.client;

  /// Get current configuration
  String? get host => _host;
  String? get database => _database;
  stdb.AuthTokenStore? get authStorage => _authStorage;

  /// Dispose resources
  Future<void> dispose() async {
    debugLogger.info('REPO', 'Disposing repository');
    resetConnection();
    _syncStateSubject.close();
    for (final lane in _lanes) {
      lane.clientNotifier.dispose();
      lane.appliedQuerySets.dispose();
      await lane.offlineStorage?.dispose();
      lane.offlineStorage = null;
    }
  }

  @visibleForTesting
  Future<void> migrateOfflineCachesForTest(String appDirPath) async {
    await _adoptPreLaneCache(appDirPath);
    await _sweepOrphanedCaches(appDirPath);
  }

  Future<void> initializeOfflineFirst() async {
    if (_notesLane.client != null) return;
    if (!await isConfigured()) {
      debugLogger
          .connection('initializeOfflineFirst: not configured, skipping');
      return;
    }
    final storage = _authStorage ?? SharedPreferencesTokenStore();
    for (final lane in _lanes) {
      try {
        lane.offlineStorage ??= await _createOfflineStorage(lane.storageSuffix);
        await _createClient(lane, storage);
      } catch (e, st) {
        debugLogger.error(
            'CONN', lane.tag('initializeOfflineFirst failed'), '$e\n$st');
      }
    }
  }

  /// Injects [storage] as the notes lane's cache. The chat lane gets its own
  /// in-memory instance rather than sharing this one, mirroring production,
  /// where the two lanes never share a cache.
  @visibleForTesting
  void debugSetOfflineStorage(OfflineStorage storage) {
    _notesLane.offlineStorage = storage;
    _chatLane.offlineStorage = InMemoryOfflineStorage();
  }

  @visibleForTesting
  int get debugConnectAttempts => _notesLane.connectAttempts;

  @visibleForTesting
  bool get debugRetryScheduled => _notesLane.retryScheduled;

  void _flushDeferredUnsubscribes(_ClientLane lane) {
    final client = lane.client;
    if (client == null || lane.deferredUnsubscribes.isEmpty) return;
    final ids = lane.deferredUnsubscribes.toList();
    lane.deferredUnsubscribes.clear();
    for (final id in ids) {
      client.subscriptions.unsubscribe(id);
    }
  }

  Future<void> _tryReconnectLane(
    _ClientLane lane, {
    bool resetAttempts = false,
    bool force = false,
  }) async {
    debugLogger.connection(lane.tag('tryReconnect() called'));
    if (resetAttempts) lane.retryAttempt = 0;
    final client = lane.client;
    if (client == null) {
      debugLogger.connection(lane.tag('tryReconnect: client is null, returning'));
      return;
    }

    final state = client.connection.state;
    debugLogger.connection(lane.tag('tryReconnect: state=${state.displayName}'));

    if (force && state is stdb.Reconnecting) {
      debugLogger.connection(
        lane.tag('tryReconnect: force clearing stale Reconnecting state'),
      );
      lane.retryScheduled = false;
      await client.disconnect();
    } else if (state.isConnecting) {
      debugLogger
          .connection(lane.tag('tryReconnect: already connecting, returning'));
      return;
    }

    if (lane.retryScheduled) {
      debugLogger.connection(
          lane.tag('tryReconnect: retry already scheduled, returning'));
      return;
    }

    if (state.isConnected) {
      // State says connected but iOS/Android may have silently killed the
      // socket's read-half while backgrounded. Force a round-trip probe;
      // if the server doesn't answer within the timeout, fall through to
      // reconnect.
      debugLogger.connection(
          lane.tag('tryReconnect: running checkHealth (timeout=2s)'));
      bool healthy;
      try {
        healthy = await client.subscriptions
            .checkHealth(timeout: const Duration(seconds: 2));
      } catch (e, st) {
        debugLogger.error(
          'CONN',
          lane.tag('tryReconnect: checkHealth threw'),
          '$e\n$st',
        );
        healthy = false;
      }
      debugLogger.connection(lane.tag('tryReconnect: checkHealth=$healthy'));
      if (healthy) {
        debugLogger.connection(lane.tag('checkHealth ok, skipping reconnect'));
        lane.retryAttempt = 0;
        return;
      }
      debugLogger.warning(
        'CONN',
        lane.tag('checkHealth failed, connection is silently dead - reconnecting'),
      );
    }

    debugLogger.connection(lane.tag('Attempting to reconnect...'));
    final reconnectSpan = debugLogger.span('CONN', lane.tag('reconnect'));
    try {
      await client.connection.reconnect();
      reconnectSpan.end('state=${client.connection.state.displayName}');
      debugLogger.connection(
        lane.tag(
            'tryReconnect: reconnect() completed, state=${client.connection.state.displayName}'),
      );
      if (client.connection.state.isConnected) {
        lane.retryAttempt = 0;
      } else {
        _scheduleRetry(lane, 'reconnect completed but still disconnected');
      }
    } on SpacetimeDbAuthException {
      reconnectSpan.end('auth expired');
      debugLogger.warning('AUTH',
          lane.tag('Auth expired during reconnect - escalating to repo level'));
      await _handleAuthError();
    } on SpacetimeDbException catch (e) {
      reconnectSpan.end('failed: $e');
      _scheduleRetry(lane, e.toString());
    } catch (e, st) {
      reconnectSpan.end('failed: $e');
      debugLogger.error(
        'CONN',
        lane.tag('tryReconnect: reconnect() threw unexpected exception'),
        '$e\n$st',
      );
      _scheduleRetry(lane, e.toString());
    }
  }

  Future<void> _handleAppPausedLane(_ClientLane lane) async {
    final client = lane.client;
    if (client == null) return;
    if (client.connection.state is stdb.Disconnected) return;
    debugLogger.connection(
        lane.tag('App paused - disconnecting to avoid stale state'));
    lane.retryScheduled = false;
    try {
      await client.disconnect();
    } on SpacetimeDbException catch (e) {
      debugLogger.error('CONN', lane.tag('Error disconnecting on pause: $e'));
    }
  }

  /// Reset one lane. Deliberately does NOT null [_ClientLane.offlineStorage] —
  /// the cache must survive a reconnect so a rebuilt client still hydrates
  /// from disk before its first frame.
  void _resetLane(_ClientLane lane) {
    for (final sub in lane.subscriptions) {
      sub.cancel();
    }
    lane.subscriptions.clear();
    lane.querySetOwners.clear();
    lane.deferredUnsubscribes.clear();
    lane.appliedQuerySets.value = const {};
    lane.hydrationSpan?.end('aborted: connection reset');
    lane.hydrationSpan = null;

    final client = lane.client;
    if (client != null) {
      try {
        client.disconnect();
      } on SpacetimeDbException catch (e) {
        debugLogger.error('CONN', lane.tag('Error disconnecting client: $e'));
      }
      lane.client = null;
      lane.clientNotifier.value = null;
    }

    lane.nonTableListenersRegistered = false;
  }

  /// Watch OS-level network connectivity. When the device transitions from
  /// offline to online, kick a reconnect immediately — this covers the
  /// cold-launched-while-offline case where the SDK never had a live socket
  /// to auto-reconnect, so nothing else would trigger recovery until the app
  /// was next resumed.
  void _startConnectivityWatch() {
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
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
    if (_notesLane.client != null) {
      final state = _notesLane.client!.connection.state;
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
        debugLogger.warning('CONN', 'Auth error - reconnecting in place');
        await tryReconnect();
        return;
      }

      if (state is stdb.Disconnected) {
        debugLogger.connection(
            '_ensureConnected Disconnected: hasOfflineStorage=${_notesLane.client!.hasOfflineStorage}');
        if (!_notesLane.hasEverConnected && !_notesLane.initialConnectAttempted) {
          _notesLane.initialConnectAttempted = true;
          debugLogger.connection(
              'cache-hydrated client has never connected - connecting now');
          await Future.wait([
            for (final lane in _lanes)
              if (lane.client != null && !lane.hasEverConnected)
                _connectClient(lane, lane.client!).catchError((e, st) {
                  debugLogger.error(
                    'CONN',
                    lane.tag(
                        'initial connect of cache-hydrated client failed - SDK '
                        'retried and gave up; FatalError re-arms recovery'),
                    '$e\n$st',
                  );
                }),
          ]);
          return;
        }
        if (!_notesLane.hasEverConnected) {
          debugLogger.warning('CONN',
              'Lane never connected after its initial attempt - retrying via tryReconnect');
          await tryReconnect();
          return;
        }
        if (_notesLane.client!.hasOfflineStorage) {
          debugLogger.connection(
              'Offline mode: using existing client, re-arming retry ladder');
          _scheduleRetry(_notesLane, 'disconnected with offline cache');
          return;
        }
        debugLogger.warning('CONN',
            'DEGRADED CONNECTION: ${state.displayName} - reconnecting in place');
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

  /// Build the offline cache for one lane. The [suffix] is load-bearing: the
  /// retention `__tags__<table>` sidecars are named by table alone, so the
  /// basePath is the only thing keeping the two lanes' caches apart. Sharing a
  /// path would also mean two independent LockManagers over the same files.
  static const _laneCacheSuffixes = ['_notes', '_chat'];

  /// Adopts the pre-lane single-client cache as the notes lane's cache, so the
  /// first launch after the split still paints from disk instead of refetching
  /// the whole snapshot. Only runs when the old directory exists and the new
  /// one does not.
  Future<void> _adoptPreLaneCache(String appDirPath) async {
    try {
      final legacy = Directory('$appDirPath/spacenotes_offline');
      if (!await legacy.exists()) return;
      final adopted = '$appDirPath/spacenotes_offline_notes';
      if (await Directory(adopted).exists()) {
        await legacy.delete(recursive: true);
        debugLogger.info(
            'STORAGE', 'Removed superseded pre-lane offline cache');
        return;
      }
      await legacy.rename(adopted);
      debugLogger.info('STORAGE', 'Adopted pre-lane offline cache', adopted);
    } catch (e) {
      debugLogger.warning(
          'STORAGE', 'Could not adopt pre-lane cache', e.toString());
    }
  }

  /// Removes `spacenotes_offline*` directories no live lane claims, so a
  /// renamed or retired lane cannot strand its cache on disk forever.
  Future<void> _sweepOrphanedCaches(String appDirPath) async {
    try {
      final live = _laneCacheSuffixes
          .map((suffix) => 'spacenotes_offline$suffix')
          .toSet();
      await for (final entry in Directory(appDirPath).list()) {
        if (entry is! Directory) continue;
        final name = entry.path.split(Platform.pathSeparator).last;
        if (!name.startsWith('spacenotes_offline')) continue;
        if (name == 'spacenotes_offline') continue;
        if (live.contains(name)) continue;
        await entry.delete(recursive: true);
        debugLogger.info('STORAGE', 'Removed orphaned offline cache', name);
      }
    } catch (e) {
      debugLogger.warning(
          'STORAGE', 'Orphaned cache sweep failed', e.toString());
    }
  }

  Future<OfflineStorage?> _createOfflineStorage(String suffix) async {
    if (kIsWeb) {
      debugLogger.info(
          'STORAGE', 'Web platform - using InMemoryOfflineStorage');
      return InMemoryOfflineStorage();
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final storagePath = '${appDir.path}/spacenotes_offline$suffix';
      await _adoptPreLaneCache(appDir.path);
      await _sweepOrphanedCaches(appDir.path);
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

  Future<SpacetimeDbClient> _createClient(
    _ClientLane lane,
    stdb.AuthTokenStore storage,
  ) async {
    debugLogger.connection(
      lane.tag('client create: starting'),
      'offlineStorage=${lane.offlineStorage != null}',
    );
    final client = await SpacetimeDbClient.create(
      host: _host!,
      database: _database!,
      authStorage: storage,
      offlineStorage: lane.offlineStorage,
      retainRowsOnUnsubscribe: true,
      ssl: false,
      config: _connectionConfig,
    );

    lane.client = client;
    lane.clientNotifier.value = client;
    debugLogger.connection(
      lane.tag('client create: visible to UI'),
      'spaceFile=${client.spaceFile.rows.value.length} '
      'folder=${client.folder.rows.value.length} '
      'message=${client.message.rows.value.length}',
    );
    _registerNonTableListenersFor(lane);

    return client;
  }

  Future<void> _connectClient(_ClientLane lane, SpacetimeDbClient client) async {
    lane.connectAttempts++;
    try {
      await client.connect(
        initialSubscriptions: lane.initialSubscriptions,
        subscriptionTimeout: const Duration(seconds: 15),
      );
    } on SpacetimeDbAuthException {
      await _recoverFromStaleToken(lane);
    }
    lane.hasEverConnected = true;
  }

  /// Both lanes present the same bearer token and so resolve to the same
  /// server identity. Clearing it is therefore a repository-level act: a lane
  /// that reconnected alone on a cleared token would be minted a fresh
  /// anonymous identity, leaving one device holding two identities.
  Future<void> _clearSharedToken() async {
    final storage = _authStorage ?? SharedPreferencesTokenStore();
    await storage.clearToken();
  }

  /// Recover from a 401 on connect: the stored token belongs to a database
  /// that no longer exists (a wipe/republish), so it must be dropped and a
  /// fresh identity acquired.
  ///
  /// This is repository-level and idempotent across concurrent lanes on
  /// purpose. Both lanes dial together and present the same token, so a stale
  /// token fails on BOTH sockets at once. If each lane cleared the shared token
  /// and re-dialled alone, each would be minted its OWN anonymous identity and
  /// the device would hold two — which the server's per-connection presence fix
  /// does not cover, since it assumes one token yields one identity across both
  /// sockets. So the first lane here clears once and re-dials every lane
  /// together; a lane arriving while that is in flight awaits it instead of
  /// starting a second recovery.
  Future<void> _recoverFromStaleToken(_ClientLane lane) async {
    final inFlight = _staleTokenRecovery;
    if (inFlight != null) {
      debugLogger.connection(lane.tag(
          'Auth failure (401) on connect - joining in-flight shared-token '
          'recovery so both lanes land on ONE identity'));
      await inFlight;
      return;
    }

    final recovery = _runStaleTokenRecovery(lane);
    _staleTokenRecovery = recovery;
    try {
      await recovery;
    } finally {
      _staleTokenRecovery = null;
    }
  }

  Future<void> _runStaleTokenRecovery(_ClientLane trigger) async {
    debugLogger.warning(
      'AUTH',
      trigger.tag('Auth failure (401) on connect - clearing stale token once '
          'and re-dialling BOTH lanes onto a single fresh identity'),
    );
    await _clearSharedToken();
    for (final lane in _lanes) {
      lane.client?.connection.clearToken();
    }

    await Future.wait([
      for (final lane in _lanes)
        if (lane.client != null) _redialAfterTokenClear(lane, lane.client!),
    ]);
  }

  Future<void> _redialAfterTokenClear(
    _ClientLane lane,
    SpacetimeDbClient client,
  ) async {
    if (client.connection.state.isConnected) return;
    lane.connectAttempts++;
    await client.connect(
      initialSubscriptions: lane.initialSubscriptions,
      subscriptionTimeout: const Duration(seconds: 15),
    );
    debugLogger
        .connection(lane.tag('Reconnected with fresh anonymous identity'));
  }

  Future<SpacetimeDbClient> _createAndConnectClient(
    _ClientLane lane,
    stdb.AuthTokenStore storage,
  ) async {
    final client = await _createClient(lane, storage);
    await _connectClient(lane, client);
    return client;
  }

  Future<void> _connect() async {
    debugLogger.connection(
        'Connecting to SpacetimeDB', 'host=$_host, db=$_database');

    final storage = _authStorage ?? SharedPreferencesTokenStore();

    await Future.wait([
      for (final lane in _lanes) _connectLane(lane, storage),
    ]);

    if (_notesLane.client?.connection.state.isConnected ?? false) {
      await ensureGeneralNotesFolder();
    }
  }

  Future<bool> _connectLane(
    _ClientLane lane,
    stdb.AuthTokenStore storage,
  ) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    try {
      lane.offlineStorage ??= await _createOfflineStorage(lane.storageSuffix);

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await _createAndConnectClient(lane, storage);
          break;
        } catch (e) {
          if (attempt < maxRetries) {
            debugLogger.warning(
                'CONN',
                lane.tag(
                    'Attempt $attempt failed: $e, retrying in ${retryDelay.inSeconds}s'));
            await Future.delayed(retryDelay);
          } else {
            rethrow;
          }
        }
      }

      final isConnected = lane.client?.connection.state.isConnected ?? false;
      if (isConnected) {
        debugLogger
            .connection(lane.tag('Successfully connected to SpacetimeDB'));
      } else {
        debugLogger.connection(
            lane.tag('Operating in offline mode (cached data available)'));
      }

      _registerNonTableListenersFor(lane);
      return isConnected;
    } on SpacetimeDbException catch (e) {
      debugLogger.error(
          'CONN', lane.tag('Error connecting to SpacetimeDB'), e.toString());
      if (lane.client != null) {
        debugLogger.warning(
            'CONN',
            lane.tag('Initial connect failed offline - SDK retried and gave '
                'up; client stays usable offline'));
        return false;
      }
      rethrow;
    }
  }

  /// Listeners that are not watchable via the per-table ValueNotifier API.
  /// Table row/event watching happens directly in providers via `client.note.rows`
  /// and `client.note.lastBatch`.
  void _registerNonTableListenersFor(_ClientLane lane) {
    final client = lane.client;
    if (client == null) return;
    if (lane.nonTableListenersRegistered) return;
    lane.nonTableListenersRegistered = true;

    final ready = client.subscriptions.subscriptionsReady;
    void onReady() {
      debugLogger
          .connection(lane.tag('subscriptionsReady -> ${ready.value}'));
      if (ready.value) {
        lane.hydrationSpan?.end(_hydrationSummary(lane, client));
        lane.hydrationSpan = null;
        _flushDeferredUnsubscribes(lane);
      }
    }

    ready.addListener(onReady);
    onReady();

    if (client.hasOfflineStorage && identical(lane, _notesLane)) {
      final syncStateSub = client.onSyncStateChanged.listen((state) {
        debugLogger.debug(
          'SYNC_SDK',
          lane.tag(
              'SDK sync state changed: isSyncing=${state.isSyncing}, pending=${state.pendingCount}, hasError=${state.hasError}'),
        );
        _syncStateSubject.add(state);
      });
      lane.subscriptions.add(syncStateSub);
      _syncStateSubject.add(client.syncState);
    }

    final connectionStateSub = client.connection.onStateChanged.listen((state) {
      debugLogger.connection(lane.tag('state -> ${state.displayName}'));
      if (state is stdb.Connected) {
        lane.hydrationSpan?.end('superseded by new Connected');
        lane.hydrationWireBytes = 0;
        lane.hydrationSpan =
            debugLogger.span('HYDRATION', lane.tag('connect-hydration'));
        _authErrorAttempts = 0;
        return;
      }
      if (lane.hydrationSpan != null) {
        lane.hydrationSpan!.end('aborted: ${state.displayName}');
        lane.hydrationSpan = null;
      }
      if (state is stdb.AuthError) {
        _handleAuthErrorGated();
        return;
      }
      if (state is stdb.FatalError) {
        debugLogger.warning(
            'CONN',
            lane.tag(
                'Fatal error - re-arming repo retry to recover when server returns'));
        _scheduleRetry(lane, 'fatal error - re-arming');
      }
    });
    lane.subscriptions.add(connectionStateSub);

    final subscribeAppliedSub =
        client.subscriptions.onSubscribeApplied.listen((applied) {
      lane.markApplied(applied.querySetId);
      var bytes = 0;
      final tables = <String>[];
      for (final table in applied.rows.tables) {
        bytes += table.rows.rowsData.length;
        tables.add('${table.tableName}=${table.rows.rowsData.length}B');
      }
      lane.hydrationWireBytes += bytes;
      final summary =
          'SubscribeApplied querySetId=${applied.querySetId} ${tables.join(' ')} wire=${bytes}B';
      if (lane.hydrationSpan != null) {
        lane.hydrationSpan!.lap(summary);
      } else {
        debugLogger.info('HYDRATION', lane.tag(summary));
      }
    });
    lane.subscriptions.add(subscribeAppliedSub);

    debugLogger.sync(lane.tag('Non-table listeners registered'));
  }

  /// Row counts come from the cache rather than the wire so the end line
  /// reports what the app can actually see once hydration completes.
  String _hydrationSummary(_ClientLane lane, SpacetimeDbClient client) {
    final rows = identical(lane, _notesLane)
        ? 'space_file=${client.spaceFile.rows.value.length} folder=${client.folder.rows.value.length}'
        : 'agent=${client.agent.rows.value.length} message=${client.message.rows.value.length}';
    return 'subscriptionsReady rows: $rows wire=${lane.hydrationWireBytes}B';
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
    await _clearSharedToken();
    resetConnection();
    await connectAndGetInitialData();
  }

  /// Schedule the next reconnect attempt. Fixed 5s interval, up to
  /// [_maxRetryAttempts] (~42 min of trying) — SpaceNotes reconnects
  /// aggressively whether the drop was from a live connection or a failed
  /// cold start. The loop stops once connected (checked at the top of
  /// [tryReconnect]) or once the cap is hit.
  static const _retryInterval = Duration(seconds: 5);
  static const _maxRetryAttempts = 500;

  void _scheduleRetry(_ClientLane lane, String reason) {
    if (lane.retryScheduled) return;
    if (lane.retryAttempt >= _maxRetryAttempts) {
      debugLogger.warning(
          'CONN',
          lane.tag(
              'Reconnect cap ($_maxRetryAttempts) reached - stopping retry loop until next resume/connectivity event'));
      return;
    }
    lane.retryAttempt += 1;
    lane.retryScheduled = true;
    debugLogger.warning(
      'CONN',
      lane.tag(
          'Reconnection failed: $reason, retrying in ${_retryInterval.inSeconds}s (attempt ${lane.retryAttempt}/$_maxRetryAttempts)'),
    );
    Future.delayed(_retryInterval, () {
      lane.retryScheduled = false;
      final client = lane.client;
      if (client == null) return;
      if (client.connection.state.isConnected) {
        lane.retryAttempt = 0;
        return;
      }
      _tryReconnectLane(lane);
    });
  }
}
