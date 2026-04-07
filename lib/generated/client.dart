// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: avoid_print

import 'dart:async';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import 'reducers.dart';
import 'reducer_args.dart';
import 'connected_user.dart';
import 'folder.dart';
import 'audio_frame.dart';
import 'note.dart';
import 'user_profile.dart';
import 'video_frame.dart';
import 'call_session.dart';

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

  TableCache<ConnectedUser> get connectedUser {
    return subscriptions.cache
        .getTableByTypedName<ConnectedUser>('connected_user');
  }

  TableCache<Folder> get folder {
    return subscriptions.cache.getTableByTypedName<Folder>('folder');
  }

  TableCache<AudioFrame> get audioFrame {
    return subscriptions.cache.getTableByTypedName<AudioFrame>('audio_frame');
  }

  TableCache<Note> get note {
    return subscriptions.cache.getTableByTypedName<Note>('note');
  }

  TableCache<UserProfile> get userProfile {
    return subscriptions.cache.getTableByTypedName<UserProfile>('user_profile');
  }

  TableCache<VideoFrame> get videoFrame {
    return subscriptions.cache.getTableByTypedName<VideoFrame>('video_frame');
  }

  TableCache<CallSession> get callSession {
    return subscriptions.cache.getTableByTypedName<CallSession>('call_session');
  }

  static Future<SpacetimeDbClient> connect({
    required String host,
    required String database,
    AuthTokenStore? authStorage,
    OfflineStorage? offlineStorage,
    bool ssl = false,
    ConnectionConfig config = const ConnectionConfig(),
    List<String>? initialSubscriptions,
    Duration subscriptionTimeout = const Duration(seconds: 10),
    void Function(SpacetimeDbClient client)? onCacheLoaded,
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

// Auto-register table decoders
    subscriptionManager.cache.registerDecoder<ConnectedUser>(
        'connected_user', ConnectedUserDecoder());
    subscriptionManager.cache
        .registerDecoder<Folder>('folder', FolderDecoder());
    subscriptionManager.cache.registerDecoder<AudioFrame>(
        'audio_frame', AudioFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache.registerDecoder<Note>('note', NoteDecoder());
    subscriptionManager.cache
        .registerDecoder<UserProfile>('user_profile', UserProfileDecoder());
    subscriptionManager.cache.registerDecoder<VideoFrame>(
        'video_frame', VideoFrameDecoder(),
        isEvent: true);
    subscriptionManager.cache
        .registerDecoder<CallSession>('call_session', CallSessionDecoder());

// Auto-register view decoders

// Auto-register reducer argument decoders
    subscriptionManager.reducerRegistry.register(acceptCallDef);
    subscriptionManager.reducerRegistry.register(appendToNoteDef);
    subscriptionManager.reducerRegistry.register(clearAllDef);
    subscriptionManager.reducerRegistry.register(createFolderDef);
    subscriptionManager.reducerRegistry.register(createNoteDef);
    subscriptionManager.reducerRegistry.register(deleteFolderDef);
    subscriptionManager.reducerRegistry.register(deleteNoteDef);
    subscriptionManager.reducerRegistry.register(endCallDef);
    subscriptionManager.reducerRegistry.register(findReplaceInNoteDef);
    subscriptionManager.reducerRegistry.register(getRecentNotesDef);
    subscriptionManager.reducerRegistry.register(moveFolderDef);
    subscriptionManager.reducerRegistry.register(moveNoteDef);
    subscriptionManager.reducerRegistry.register(prependToNoteDef);
    subscriptionManager.reducerRegistry.register(renameNoteDef);
    subscriptionManager.reducerRegistry.register(requestCallDef);
    subscriptionManager.reducerRegistry.register(sendAudioFrameDef);
    subscriptionManager.reducerRegistry.register(sendVideoFrameDef);
    subscriptionManager.reducerRegistry.register(setDisplayNameDef);
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

    subscriptionManager.onIdentityToken.listen((msg) async {
      await storage.saveToken(msg.token);
      connection.updateToken(msg.token);
    });

    if (offlineStorage != null) {
      await subscriptionManager.loadFromOfflineCache();
      onCacheLoaded?.call(client);
    }

    try {
      await connection.connect().timeout(config.connectTimeout);
      if (initialSubscriptions != null && initialSubscriptions.isNotEmpty) {
        await subscriptionManager
            .subscribe(initialSubscriptions)
            .timeout(subscriptionTimeout);
      }
    } catch (e) {
      if (offlineStorage != null) {
        print('📴 Connection failed, operating in offline mode: $e');
      } else {
        rethrow;
      }
    }

    return client;
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
