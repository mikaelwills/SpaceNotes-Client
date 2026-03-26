// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import 'reducers.dart';
import 'reducer_args.dart';
import 'folder.dart';
import 'user_profile.dart';
import 'video_frame.dart';
import 'connected_user.dart';
import 'note.dart';
import 'audio_frame.dart';
import 'call_session.dart';

class SpacetimeDbClient {
  final SpacetimeDbConnection connection;
  final SubscriptionManager subscriptions;
  final AuthTokenStore _authStorage;
  final bool _ssl; // Store SSL state for OIDC generation
  late final Reducers reducers;

  /// Access to ReducerEmitter for event-driven patterns
  ReducerEmitter get reducerEmitter => subscriptions.reducerEmitter;

  /// Current user identity (32-byte public key hash)
  ///
  /// Available after connection is established. Returns null before first IdentityToken message.
  ///
  /// Example:
  /// ```dart
  /// // Check ownership
  /// if (note.ownerId == client.identity?.toHexString) {
  ///   // User owns this note
  /// }
  ///
  /// // Display in UI
  /// print("User: ${client.identity?.toAbbreviated}"); // "2ab4...9f1c"
  /// ```
  Identity? get identity => subscriptions.identity;

  /// Current connection address (16-byte connection ID as hex string)
  ///
  /// Available after connection is established. Returns null before first IdentityToken message.
  String? get address => subscriptions.address;

  /// Current authentication token (JWT string)
  ///
  /// Available after connection is established. Returns null if not authenticated.
  String? get token => connection.token;

  /// Whether offline storage is enabled
  bool get hasOfflineStorage => subscriptions.hasOfflineStorage;

  /// Current sync state for offline mutations
  SyncState get syncState => subscriptions.syncState;

  /// Stream of sync state changes
  Stream<SyncState> get onSyncStateChanged => subscriptions.onSyncStateChanged;

  /// Stream of individual mutation sync results
  Stream<MutationSyncResult> get onMutationSyncResult => subscriptions.onMutationSyncResult;

  TableCache<Folder> get folder {
    return subscriptions.cache.getTableByTypedName<Folder>('folder');
  }

  TableCache<UserProfile> get userProfile {
    return subscriptions.cache.getTableByTypedName<UserProfile>('user_profile');
  }

  TableCache<VideoFrame> get videoFrame {
    return subscriptions.cache.getTableByTypedName<VideoFrame>('video_frame');
  }

  TableCache<ConnectedUser> get connectedUser {
    return subscriptions.cache.getTableByTypedName<ConnectedUser>('connected_user');
  }

  TableCache<Note> get note {
    return subscriptions.cache.getTableByTypedName<Note>('note');
  }

  TableCache<AudioFrame> get audioFrame {
    return subscriptions.cache.getTableByTypedName<AudioFrame>('audio_frame');
  }

  TableCache<CallSession> get callSession {
    return subscriptions.cache.getTableByTypedName<CallSession>('call_session');
  }

  SpacetimeDbClient._({
    required this.connection,
    required this.subscriptions,
    required AuthTokenStore authStorage,
    required bool ssl,
  })  : _authStorage = authStorage,
        _ssl = ssl {
    // Initialize Reducers with ReducerCaller and ReducerEmitter
    reducers = Reducers(subscriptions.reducers, subscriptions.reducerEmitter);
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
    // Setup storage (default to in-memory)
    final storage = authStorage ?? InMemoryTokenStore();

    // Try to load existing token
    final savedToken = await storage.loadToken();

    // Connect with token
    final connection = SpacetimeDbConnection(
      host: host,
      database: database,
      initialToken: savedToken,
      ssl: ssl, // Pass SSL config to connection
      config: config, // Pass connection config
    );

    final subscriptionManager = SubscriptionManager(connection, offlineStorage: offlineStorage);

    // Auto-register table decoders
    subscriptionManager.cache.registerDecoder<Folder>('folder', FolderDecoder());
    subscriptionManager.cache.registerDecoder<UserProfile>('user_profile', UserProfileDecoder());
    subscriptionManager.cache.registerDecoder<VideoFrame>('video_frame', VideoFrameDecoder(), isEvent: true);
    subscriptionManager.cache.registerDecoder<ConnectedUser>('connected_user', ConnectedUserDecoder());
    subscriptionManager.cache.registerDecoder<Note>('note', NoteDecoder());
    subscriptionManager.cache.registerDecoder<AudioFrame>('audio_frame', AudioFrameDecoder(), isEvent: true);
    subscriptionManager.cache.registerDecoder<CallSession>('call_session', CallSessionDecoder());

    // Auto-register view decoders

    // Auto-register reducer argument decoders
    subscriptionManager.reducerRegistry.registerDecoder('accept_call', AcceptCallArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('append_to_note', AppendToNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('clear_all', ClearAllArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('create_folder', CreateFolderArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('create_note', CreateNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('delete_folder', DeleteFolderArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('delete_note', DeleteNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('end_call', EndCallArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('find_replace_in_note', FindReplaceInNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('get_recent_notes', GetRecentNotesArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('move_folder', MoveFolderArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('move_note', MoveNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('prepend_to_note', PrependToNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('rename_note', RenameNoteArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('request_call', RequestCallArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('send_audio_frame', SendAudioFrameArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('send_video_frame', SendVideoFrameArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('set_display_name', SetDisplayNameArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('update_note_content', UpdateNoteContentArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('update_note_path', UpdateNotePathArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('upsert_folder', UpsertFolderArgsDecoder());
    subscriptionManager.reducerRegistry.registerDecoder('upsert_note', UpsertNoteArgsDecoder());

    final client = SpacetimeDbClient._(
      connection: connection,
      subscriptions: subscriptionManager,
      authStorage: storage,
      ssl: ssl,
    );

    // Auto-save new tokens
    subscriptionManager.onIdentityToken.listen((msg) async {
      await storage.saveToken(msg.token);
      connection.updateToken(msg.token);
    });

    // Load cached data before connecting (for offline-first support)
    if (offlineStorage != null) {
      await subscriptionManager.loadFromOfflineCache();
      onCacheLoaded?.call(client);
    }

    // Connect and subscribe - with offline support, this is non-blocking on failure
    try {
      await connection.connect().timeout(config.connectTimeout);
      if (initialSubscriptions != null && initialSubscriptions.isNotEmpty) {
        await subscriptionManager.subscribe(initialSubscriptions).timeout(subscriptionTimeout);
      }
    } catch (e) {
      if (offlineStorage != null) {
        // Offline mode: connection failed but we have cached data, continue in offline mode
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

  /// Logout - clear stored token and disconnect
  ///
  /// This clears the authentication token from storage and disconnects
  /// from the server. On next connect, the server will assign a new
  /// anonymous identity.
  Future<void> logout() async {
    await _authStorage.clearToken();
    await connection.disconnect();
  }

  /// Get authentication URL for OAuth/OIDC provider.
  ///
  /// Example:
  /// ```dart
  /// final url = client.getAuthUrl('google');
  /// await launchUrl(Uri.parse(url)); // Open in browser
  /// ```
  String getAuthUrl(String provider, {String? redirectUri}) {
    final helper = OidcHelper(
      host: connection.host,
      database: connection.database,
      ssl: _ssl, // Uses the captured SSL state
    );
    return helper.getAuthUrl(provider, redirectUri: redirectUri);
  }

  /// Parse token from OAuth callback URL.
  ///
  /// Example:
  /// ```dart
  /// // After user authenticates, your app receives callback:
  /// final token = client.parseTokenFromCallback('myapp://callback?token=abc123');
  /// if (token != null) {
  ///   // Save and reconnect with new token
  /// }
  /// ```
  String? parseTokenFromCallback(String callbackUrl) {
    final helper = OidcHelper(
      host: connection.host,
      database: connection.database,
      ssl: _ssl,
    );
    return helper.parseTokenFromCallback(callbackUrl);
  }
}
