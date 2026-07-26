// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: avoid_print

import 'dart:async';
import 'package:spacetimedb_sdk/codegen.dart';
import 'reducers.dart';
import 'reducer_args.dart';
import 'message.dart';
import 'audio_frame.dart';
import 'user_profile.dart';
import 'folder.dart';
import 'video_frame.dart';
import 'permission_request.dart';
import 'agent_activity.dart';
import 'call_session.dart';
import 'connected_user.dart';
import 'question_request.dart';
import 'tool_event.dart';
import 'space_file.dart';
import 'agent.dart';
import 'message_image.dart';

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

  TableCache<Message> get message {
    return subscriptions.cache.getTableByTypedName<Message>('message');
  }

  TableCache<AudioFrame> get audioFrame {
    return subscriptions.cache.getTableByTypedName<AudioFrame>('audio_frame');
  }

  TableCache<UserProfile> get userProfile {
    return subscriptions.cache.getTableByTypedName<UserProfile>('user_profile');
  }

  TableCache<Folder> get folder {
    return subscriptions.cache.getTableByTypedName<Folder>('folder');
  }

  TableCache<VideoFrame> get videoFrame {
    return subscriptions.cache.getTableByTypedName<VideoFrame>('video_frame');
  }

  TableCache<PermissionRequest> get permissionRequest {
    return subscriptions.cache
        .getTableByTypedName<PermissionRequest>('permission_request');
  }

  TableCache<AgentActivity> get agentActivity {
    return subscriptions.cache
        .getTableByTypedName<AgentActivity>('agent_activity');
  }

  TableCache<CallSession> get callSession {
    return subscriptions.cache.getTableByTypedName<CallSession>('call_session');
  }

  TableCache<ConnectedUser> get connectedUser {
    return subscriptions.cache
        .getTableByTypedName<ConnectedUser>('connected_user');
  }

  TableCache<QuestionRequest> get questionRequest {
    return subscriptions.cache
        .getTableByTypedName<QuestionRequest>('question_request');
  }

  TableCache<ToolEvent> get toolEvent {
    return subscriptions.cache.getTableByTypedName<ToolEvent>('tool_event');
  }

  TableCache<SpaceFile> get spaceFile {
    return subscriptions.cache.getTableByTypedName<SpaceFile>('space_file');
  }

  TableCache<Agent> get agent {
    return subscriptions.cache.getTableByTypedName<Agent>('agent');
  }

  TableCache<MessageImage> get messageImage {
    return subscriptions.cache
        .getTableByTypedName<MessageImage>('message_image');
  }

  static Future<SpacetimeDbClient> create({
    required String host,
    required String database,
    AuthTokenStore? authStorage,
    OfflineStorage? offlineStorage,
    OfflineQueuePolicy queuePolicy = const OfflineQueuePolicy(),
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
    final subscriptionManager = SubscriptionManager(connection,
        offlineStorage: offlineStorage, queuePolicy: queuePolicy);

    subscriptionManager.cache
        .registerDecoder<Message>('message', MessageDecoder());
    subscriptionManager.cache.registerDecoder<AudioFrame>(
        'audio_frame', AudioFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache
        .registerDecoder<UserProfile>('user_profile', UserProfileDecoder());
    subscriptionManager.cache
        .registerDecoder<Folder>('folder', FolderDecoder());
    subscriptionManager.cache.registerDecoder<VideoFrame>(
        'video_frame', VideoFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache.registerDecoder<PermissionRequest>(
        'permission_request', PermissionRequestDecoder());
    subscriptionManager.cache.registerDecoder<AgentActivity>(
        'agent_activity', AgentActivityDecoder());
    subscriptionManager.cache
        .registerDecoder<CallSession>('call_session', CallSessionDecoder());
    subscriptionManager.cache.registerDecoder<ConnectedUser>(
        'connected_user', ConnectedUserDecoder());
    subscriptionManager.cache.registerDecoder<QuestionRequest>(
        'question_request', QuestionRequestDecoder());
    subscriptionManager.cache
        .registerDecoder<ToolEvent>('tool_event', ToolEventDecoder());
    subscriptionManager.cache
        .registerDecoder<SpaceFile>('space_file', SpaceFileDecoder());
    subscriptionManager.cache.registerDecoder<Agent>('agent', AgentDecoder());
    subscriptionManager.cache
        .registerDecoder<MessageImage>('message_image', MessageImageDecoder());

    subscriptionManager.reducerRegistry.register(acceptCallDef);
    subscriptionManager.reducerRegistry.register(appendToFileDef);
    subscriptionManager.reducerRegistry.register(clearAllDef);
    subscriptionManager.reducerRegistry.register(clearAllAgentsDef);
    subscriptionManager.reducerRegistry.register(createFileDef);
    subscriptionManager.reducerRegistry.register(createFolderDef);
    subscriptionManager.reducerRegistry.register(deleteAgentDef);
    subscriptionManager.reducerRegistry.register(deleteFileDef);
    subscriptionManager.reducerRegistry.register(deleteFolderDef);
    subscriptionManager.reducerRegistry.register(editMessageDef);
    subscriptionManager.reducerRegistry.register(endAgentDef);
    subscriptionManager.reducerRegistry.register(endCallDef);
    subscriptionManager.reducerRegistry.register(findReplaceInFileDef);
    subscriptionManager.reducerRegistry.register(getRecentFilesDef);
    subscriptionManager.reducerRegistry.register(heartbeatDef);
    subscriptionManager.reducerRegistry.register(moveFileDef);
    subscriptionManager.reducerRegistry.register(moveFolderDef);
    subscriptionManager.reducerRegistry.register(prependToFileDef);
    subscriptionManager.reducerRegistry.register(pushContextUsageDef);
    subscriptionManager.reducerRegistry.register(pushImageDef);
    subscriptionManager.reducerRegistry.register(pushMessageDef);
    subscriptionManager.reducerRegistry.register(pushStatusDef);
    subscriptionManager.reducerRegistry.register(pushToolEventDef);
    subscriptionManager.reducerRegistry.register(registerAgentDef);
    subscriptionManager.reducerRegistry.register(renameFileDef);
    subscriptionManager.reducerRegistry.register(requestCallDef);
    subscriptionManager.reducerRegistry.register(requestPermissionDef);
    subscriptionManager.reducerRegistry.register(requestQuestionDef);
    subscriptionManager.reducerRegistry.register(resolvePermissionDef);
    subscriptionManager.reducerRegistry.register(respondToQuestionDef);
    subscriptionManager.reducerRegistry.register(sendAudioFrameDef);
    subscriptionManager.reducerRegistry.register(sendVideoFrameDef);
    subscriptionManager.reducerRegistry.register(setDisplayNameDef);
    subscriptionManager.reducerRegistry.register(sweepOldMessagesDef);
    subscriptionManager.reducerRegistry.register(updateFileContentDef);
    subscriptionManager.reducerRegistry.register(updateFilePathDef);
    subscriptionManager.reducerRegistry.register(upsertFileDef);
    subscriptionManager.reducerRegistry.register(upsertFolderDef);

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
