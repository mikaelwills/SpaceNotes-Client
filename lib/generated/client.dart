// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: avoid_print

import 'dart:async';
import 'package:spacetimedb_sdk/codegen.dart';
import 'reducers.dart';
import 'reducer_args.dart';
import 'folder.dart';
import 'session_activity.dart';
import 'tool_event.dart';
import 'user_profile.dart';
import 'video_frame.dart';
import 'note.dart';
import 'audio_frame.dart';
import 'permission_request.dart';
import 'call_session.dart';
import 'message_image.dart';
import 'question_request.dart';
import 'message.dart';
import 'connected_user.dart';
import 'session.dart';

class SpacetimeDbClient {
  SpacetimeDbClient._({
    required this.connection,
    required this.subscriptions,
    required AuthTokenStore authStorage,
    required bool ssl,
  })  : _authStorage = authStorage,
        _ssl = ssl {
    reducers = Reducers(subscriptions.reducers, subscriptions.reducerEmitter);
  }

  final SpacetimeDbConnection connection;

  final SubscriptionManager subscriptions;

  final AuthTokenStore _authStorage;

  final bool _ssl;

  late final Reducers reducers;

  ReducerEmitter get reducerEmitter {
    return subscriptions.reducerEmitter;
  }

  Identity? get identity {
    return subscriptions.identity;
  }

  String? get address {
    return subscriptions.address;
  }

  String? get token {
    return connection.token;
  }

  bool get hasOfflineStorage {
    return subscriptions.hasOfflineStorage;
  }

  SyncState get syncState {
    return subscriptions.syncState;
  }

  Stream<SyncState> get onSyncStateChanged {
    return subscriptions.onSyncStateChanged;
  }

  Stream<MutationSyncResult> get onMutationSyncResult {
    return subscriptions.onMutationSyncResult;
  }

  void clearSyncErrors() {
    subscriptions.clearSyncErrors();
  }

  TableCache<Folder> get folder {
    return subscriptions.cache.getTableByTypedName<Folder>('folder');
  }

  TableCache<SessionActivity> get sessionActivity {
    return subscriptions.cache
        .getTableByTypedName<SessionActivity>('session_activity');
  }

  TableCache<ToolEvent> get toolEvent {
    return subscriptions.cache.getTableByTypedName<ToolEvent>('tool_event');
  }

  TableCache<UserProfile> get userProfile {
    return subscriptions.cache.getTableByTypedName<UserProfile>('user_profile');
  }

  TableCache<VideoFrame> get videoFrame {
    return subscriptions.cache.getTableByTypedName<VideoFrame>('video_frame');
  }

  TableCache<Note> get note {
    return subscriptions.cache.getTableByTypedName<Note>('note');
  }

  TableCache<AudioFrame> get audioFrame {
    return subscriptions.cache.getTableByTypedName<AudioFrame>('audio_frame');
  }

  TableCache<PermissionRequest> get permissionRequest {
    return subscriptions.cache
        .getTableByTypedName<PermissionRequest>('permission_request');
  }

  TableCache<CallSession> get callSession {
    return subscriptions.cache.getTableByTypedName<CallSession>('call_session');
  }

  TableCache<MessageImage> get messageImage {
    return subscriptions.cache
        .getTableByTypedName<MessageImage>('message_image');
  }

  TableCache<QuestionRequest> get questionRequest {
    return subscriptions.cache
        .getTableByTypedName<QuestionRequest>('question_request');
  }

  TableCache<Message> get message {
    return subscriptions.cache.getTableByTypedName<Message>('message');
  }

  TableCache<ConnectedUser> get connectedUser {
    return subscriptions.cache
        .getTableByTypedName<ConnectedUser>('connected_user');
  }

  TableCache<Session> get session {
    return subscriptions.cache.getTableByTypedName<Session>('session');
  }

  static Future<SpacetimeDbClient> create({
    required String host,
    required String database,
    AuthTokenStore? authStorage,
    OfflineStorage? offlineStorage,
    bool ssl = false,
    ConnectionConfig config = const ConnectionConfig(),
  }) async {
    final storage = authStorage ?? InMemoryTokenStore();
    final savedToken = await storage.loadToken();
    final connection = SpacetimeDbConnection(
      host: host,
      database: database,
      initialToken: savedToken,
      ssl: ssl,
      config: config,
    );
    final subscriptionManager =
        SubscriptionManager(connection, offlineStorage: offlineStorage);

    subscriptionManager.cache
        .registerDecoder<Folder>('folder', FolderDecoder());
    subscriptionManager.cache.registerDecoder<SessionActivity>(
        'session_activity', SessionActivityDecoder());
    subscriptionManager.cache
        .registerDecoder<ToolEvent>('tool_event', ToolEventDecoder());
    subscriptionManager.cache
        .registerDecoder<UserProfile>('user_profile', UserProfileDecoder());
    subscriptionManager.cache.registerDecoder<VideoFrame>(
        'video_frame', VideoFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache.registerDecoder<Note>('note', NoteDecoder());
    subscriptionManager.cache.registerDecoder<AudioFrame>(
        'audio_frame', AudioFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache.registerDecoder<PermissionRequest>(
        'permission_request', PermissionRequestDecoder());
    subscriptionManager.cache
        .registerDecoder<CallSession>('call_session', CallSessionDecoder());
    subscriptionManager.cache
        .registerDecoder<MessageImage>('message_image', MessageImageDecoder());
    subscriptionManager.cache.registerDecoder<QuestionRequest>(
        'question_request', QuestionRequestDecoder());
    subscriptionManager.cache
        .registerDecoder<Message>('message', MessageDecoder());
    subscriptionManager.cache.registerDecoder<ConnectedUser>(
        'connected_user', ConnectedUserDecoder());
    subscriptionManager.cache
        .registerDecoder<Session>('session', SessionDecoder());

    subscriptionManager.reducerRegistry.register(acceptCallDef);
    subscriptionManager.reducerRegistry.register(appendToNoteDef);
    subscriptionManager.reducerRegistry.register(clearAllDef);
    subscriptionManager.reducerRegistry.register(clearAllSessionsDef);
    subscriptionManager.reducerRegistry.register(createFolderDef);
    subscriptionManager.reducerRegistry.register(createNoteDef);
    subscriptionManager.reducerRegistry.register(deleteFolderDef);
    subscriptionManager.reducerRegistry.register(deleteNoteDef);
    subscriptionManager.reducerRegistry.register(deleteSessionDef);
    subscriptionManager.reducerRegistry.register(editMessageDef);
    subscriptionManager.reducerRegistry.register(endCallDef);
    subscriptionManager.reducerRegistry.register(endSessionDef);
    subscriptionManager.reducerRegistry.register(findReplaceInNoteDef);
    subscriptionManager.reducerRegistry.register(getRecentNotesDef);
    subscriptionManager.reducerRegistry.register(heartbeatDef);
    subscriptionManager.reducerRegistry.register(moveFolderDef);
    subscriptionManager.reducerRegistry.register(moveNoteDef);
    subscriptionManager.reducerRegistry.register(prependToNoteDef);
    subscriptionManager.reducerRegistry.register(pushContextUsageDef);
    subscriptionManager.reducerRegistry.register(pushImageDef);
    subscriptionManager.reducerRegistry.register(pushMessageDef);
    subscriptionManager.reducerRegistry.register(pushStatusDef);
    subscriptionManager.reducerRegistry.register(pushToolEventDef);
    subscriptionManager.reducerRegistry.register(registerSessionDef);
    subscriptionManager.reducerRegistry.register(renameNoteDef);
    subscriptionManager.reducerRegistry.register(requestCallDef);
    subscriptionManager.reducerRegistry.register(requestPermissionDef);
    subscriptionManager.reducerRegistry.register(requestQuestionDef);
    subscriptionManager.reducerRegistry.register(resolvePermissionDef);
    subscriptionManager.reducerRegistry.register(respondToQuestionDef);
    subscriptionManager.reducerRegistry.register(sendAudioFrameDef);
    subscriptionManager.reducerRegistry.register(sendVideoFrameDef);
    subscriptionManager.reducerRegistry.register(setDisplayNameDef);
    subscriptionManager.reducerRegistry.register(sweepOldMessagesDef);
    subscriptionManager.reducerRegistry.register(updateNoteContentDef);
    subscriptionManager.reducerRegistry.register(updateNotePathDef);
    subscriptionManager.reducerRegistry.register(upsertFolderDef);
    subscriptionManager.reducerRegistry.register(upsertNoteDef);

    final client = SpacetimeDbClient._(
      connection: connection,
      subscriptions: subscriptionManager,
      authStorage: storage,
      ssl: ssl,
    );

    subscriptionManager.onInitialConnection.listen((msg) async {
      await storage.saveToken(msg.token);
      connection.updateToken(msg.token);
    });

    if (offlineStorage != null) {
      await subscriptionManager.loadFromOfflineCache();
    }

    return client;
  }

  Future<void> connect({
    List<String>? initialSubscriptions,
    Duration subscriptionTimeout = const Duration(seconds: 10),
  }) async {
    await connection.connect().timeout(connection.config.connectTimeout);
    if (initialSubscriptions != null && initialSubscriptions.isNotEmpty) {
      await subscriptions
          .subscribe(initialSubscriptions)
          .timeout(subscriptionTimeout);
    }
  }

  Future<void> disconnect() async {
    await connection.disconnect();
  }

  Future<void> logout() async {
    await _authStorage.clearToken();
    await connection.disconnect();
  }

  String getAuthUrl(
    String provider, {
    String? redirectUri,
  }) {
    final helper = OidcHelper(
        host: connection.host, database: connection.database, ssl: _ssl);
    return helper.getAuthUrl(provider, redirectUri: redirectUri);
  }

  String? parseTokenFromCallback(String callbackUrl) {
    final helper = OidcHelper(
        host: connection.host, database: connection.database, ssl: _ssl);
    return helper.parseTokenFromCallback(callbackUrl);
  }
}
