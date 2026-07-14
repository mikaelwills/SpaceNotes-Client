import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';
import '../generated/client.dart';
import '../generated/message.dart';
import '../generated/reducer_args.dart';
import '../generated/permission_request.dart';
import '../generated/question_request.dart';
import '../generated/session.dart';
import '../generated/session_activity.dart';
import '../generated/tool_event.dart';
import '../services/debug_logger.dart';
import 'connection_providers.dart';
import 'notes_providers.dart';
import 'recent_sessions_provider.dart';

sealed class ChatItem {
  Int64 get timestamp;
  String get id;
}

class ChatMessageItem extends ChatItem {
  final Message message;
  ChatMessageItem(this.message);
  @override
  Int64 get timestamp => message.createdAt;
  @override
  String get id => 'msg:${message.id}';
}

class ChatToolItem extends ChatItem {
  final ToolEvent event;
  ChatToolItem(this.event);
  @override
  Int64 get timestamp => event.startedAt;
  @override
  String get id => 'tool:${event.id}';
}

class ChatPermissionItem extends ChatItem {
  final PermissionRequest request;
  ChatPermissionItem(this.request);
  @override
  Int64 get timestamp => request.createdAt;
  @override
  String get id => 'perm:${request.id}';
}

class ChatQuestionItem extends ChatItem {
  final QuestionRequest request;
  ChatQuestionItem(this.request);
  @override
  Int64 get timestamp => request.createdAt;
  @override
  String get id => 'question:${request.id}';
}

const String defaultTargetSession = 'workflow-agent';

const List<String> hostPriority = ['robert', 'M1MAX', 'Mikaels-Work'];

int _hostRank(String host) {
  final i = hostPriority.indexOf(host);
  return i == -1 ? hostPriority.length : i;
}

final sessionsProvider = Provider<List<Session>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.session.rows);
  final recent = ref.watch(recentSessionsProvider);
  final sorted = rows.toList()
    ..sort((a, b) {
      final ra = recent[a.id] ?? 0;
      final rb = recent[b.id] ?? 0;
      if (ra != rb) return rb.compareTo(ra);
      return a.baseName.toLowerCase().compareTo(b.baseName.toLowerCase());
    });
  return sorted;
});

final sessionFilterProvider = StateProvider<String>((ref) => '');

final filteredSessionsProvider = Provider<List<Session>>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final query = ref.watch(sessionFilterProvider).trim().toLowerCase();
  if (query.isEmpty) return sessions;
  return sessions.where((s) => s.id.toLowerCase().contains(query)).toList();
});

final sessionByIdProvider = Provider.family<Session?, String>((ref, id) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.session.rowNotifier(id));
});

final sessionActivityProvider =
    Provider.family<SessionActivity?, String>((ref, sessionId) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.sessionActivity.rowNotifier(sessionId));
});

final permissionByIdProvider =
    Provider.family<PermissionRequest?, String>((ref, id) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.permissionRequest.rowNotifier(id));
});

final questionByIdProvider =
    Provider.family<QuestionRequest?, String>((ref, id) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.questionRequest.rowNotifier(id));
});

/// Manual override. Null = auto-pick from sessions list.
final targetSessionOverrideProvider = StateProvider<String?>((ref) => null);

/// Session id used by the main chat. Picks the [defaultTargetSession] instance
/// on the highest-priority host (see [hostPriority]); falls back to the bare
/// default. Never falls through to an unrelated session.
final targetSessionProvider = Provider<String>((ref) {
  final override = ref.watch(targetSessionOverrideProvider);
  if (override != null) return override;
  final sessions = ref.watch(sessionsProvider);
  final candidates =
      sessions.where((s) => s.baseName == defaultTargetSession).toList()
        ..sort((a, b) => _hostRank(a.host).compareTo(_hostRank(b.host)));
  if (candidates.isNotEmpty) return candidates.first.id;
  return defaultTargetSession;
});

/// Owns the per-session chat subscription lifecycle. Watching
/// `sessionSubscriptionProvider(sessionId)` subscribes the four per-session
/// chat tables (scoped `WHERE session_id = <id>`) on first watch and
/// unsubscribes when the last watcher disposes. autoDispose ref-counts
/// watchers, so two widgets on the same session share ONE subscription.
final sessionSubscriptionProvider =
    Provider.autoDispose.family<Future<int?>, String>((ref, sessionId) {
  final repo = ref.read(notesRepositoryProvider);
  final pending = repo.subscribeSession(sessionId);
  ref.onDispose(() async {
    final qsId = await pending;
    if (qsId != null) repo.unsubscribeSession(qsId);
  });
  return pending;
});

const _warmRecentSessionCount = 10;

/// Keeps the chat tables for the most-recently-messaged sessions warm in the
/// offline cache. Subscribes the top-N recent sessions (from the persisted
/// recency map) as one query set whenever the socket is live, and re-subscribes
/// on reconnect. This is the "load recent, not everything" middle path: cold
/// start stays light, but reopening a recent session in a tunnel is instant and
/// cached — no hydration gap, no infinite spinner. Deep-history sessions
/// outside the warm set fall back to [sessionSubscriptionProvider].
final warmRecentSessionsProvider = Provider<void>((ref) {
  final connected = ref.watch(spacetimeConnectionLiveProvider).maybeWhen(
        data: (v) => v,
        orElse: () => false,
      );
  if (!connected) return;

  final recent = ref.watch(recentSessionsProvider);
  final ids = recent.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topIds = ids.take(_warmRecentSessionCount).map((e) => e.key).toList();
  if (topIds.isEmpty) return;

  final repo = ref.read(notesRepositoryProvider);
  final pending = repo.subscribeSessions(topIds);
  ref.onDispose(() async {
    final qsId = await pending;
    if (qsId != null) repo.unsubscribeSession(qsId);
  });
});

/// True once the per-session subscription's SubscribeApplied has resolved
/// (rows are in cache). Distinguishes "still hydrating" from "genuinely
/// empty" so the chat empty-state doesn't flash during the hydration gap.
final sessionHydratedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, sessionId) async {
  await ref.watch(sessionSubscriptionProvider(sessionId));
  return true;
});

final _chatIndexProvider = Provider<_ChatIndex?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) {
    debugLogger.chat('ChatIndex provider', 'client=null -> returning null');
    return null;
  }
  debugLogger.chat(
      'ChatIndex provider', 'client present -> building ChatIndex');
  final index = _ChatIndex(client);
  ref.onDispose(() {
    debugLogger.chat('ChatIndex provider', 'dispose');
    index.dispose();
  });
  return index;
});

/// Timeline of merged message + tool + permission items for a session, sorted
/// by timestamp ascending. Incrementally maintained by [_ChatIndex] — O(log n)
/// insert via binary search, zero work on changes in other sessions.
final chatTimelineBySessionProvider =
    Provider.family<List<ChatItem>, String>((ref, sessionId) {
  final index = ref.watch(_chatIndexProvider);
  if (index == null) return const [];
  final bucket = index.bucketFor(sessionId);
  void listener() => ref.invalidateSelf();
  bucket.addListener(listener);
  ref.onDispose(() => bucket.removeListener(listener));

  final sendStatus = ref.watch(chatSendStatusProvider);
  final present = {
    for (final item in bucket.items)
      if (item is ChatMessageItem) item.message.id,
  };
  final orphanedFailures = [
    for (final entry in sendStatus.values)
      if (entry.status == ChatSendStatus.failed &&
          entry.message.sessionId == sessionId &&
          !present.contains(entry.message.id))
        ChatMessageItem(entry.message),
  ];
  if (orphanedFailures.isEmpty) {
    return List<ChatItem>.unmodifiable(bucket.items);
  }
  final merged = [...bucket.items, ...orphanedFailures]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return List<ChatItem>.unmodifiable(merged);
});

/// Per-session bucket holding the merged sorted timeline. Reconciled from the
/// full `rows` snapshot of each source table — no incremental insert/update
/// delta handling. Correctness over cleverness: `onInsert`/`onUpdate` streams
/// can silently misclassify server echoes as updates when a row is already in
/// cache from offline hydration or SubscribeApplied, leaving the UI empty.
class _SessionBucket extends ChangeNotifier {
  List<ChatItem> items = const [];

  void setItems(List<ChatItem> next) {
    items = next;
    notifyListeners();
  }
}

/// Maintains per-session timelines from the source-of-truth `rows`
/// ValueListenables. On every change it re-buckets each row by sessionId and
/// publishes sorted timelines. Zero reliance on insert/update/delete stream
/// classification.
class _ChatIndex {
  final SpacetimeDbClient client;
  final Map<String, _SessionBucket> _buckets = {};
  late final VoidCallback _messageListener;
  late final VoidCallback _toolListener;
  late final VoidCallback _permListener;
  late final VoidCallback _questionListener;

  _ChatIndex(this.client) {
    debugLogger.chat(
      'ChatIndex ctor',
      'messages=${client.message.rows.value.length} '
          'tools=${client.toolEvent.rows.value.length} '
          'perms=${client.permissionRequest.rows.value.length}',
    );
    _rebuild();
    _messageListener = _rebuild;
    _toolListener = _rebuild;
    _permListener = _rebuild;
    _questionListener = _rebuild;
    client.message.rows.addListener(_messageListener);
    client.toolEvent.rows.addListener(_toolListener);
    client.permissionRequest.rows.addListener(_permListener);
    client.questionRequest.rows.addListener(_questionListener);
  }

  _SessionBucket bucketFor(String sessionId) =>
      _buckets.putIfAbsent(sessionId, _SessionBucket.new);

  void dispose() {
    client.message.rows.removeListener(_messageListener);
    client.toolEvent.rows.removeListener(_toolListener);
    client.permissionRequest.rows.removeListener(_permListener);
    client.questionRequest.rows.removeListener(_questionListener);
    for (final b in _buckets.values) {
      b.dispose();
    }
    _buckets.clear();
  }

  void _rebuild() {
    final perSession = <String, List<ChatItem>>{};

    for (final m in client.message.rows.value) {
      (perSession[m.sessionId] ??= []).add(ChatMessageItem(m));
    }
    for (final t in client.toolEvent.rows.value) {
      (perSession[t.sessionId] ??= []).add(ChatToolItem(t));
    }
    for (final p in client.permissionRequest.rows.value) {
      if (p.status == 'pending') {
        (perSession[p.sessionId] ??= []).add(ChatPermissionItem(p));
      }
    }
    for (final q in client.questionRequest.rows.value) {
      if (q.status == 'pending') {
        (perSession[q.sessionId] ??= []).add(ChatQuestionItem(q));
      }
    }

    debugLogger.chat(
      'ChatIndex rebuild',
      'msgs=${client.message.rows.value.length} '
          'tools=${client.toolEvent.rows.value.length} '
          'sessions=${perSession.length}',
    );

    for (final entry in perSession.entries) {
      entry.value.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      bucketFor(entry.key).setItems(entry.value);
    }

    for (final sessionId in _buckets.keys) {
      if (!perSession.containsKey(sessionId) &&
          _buckets[sessionId]!.items.isNotEmpty) {
        _buckets[sessionId]!.setItems(const []);
      }
    }
  }
}

DateTime timestampToDateTime(Int64 microsSinceEpoch) {
  return DateTime.fromMicrosecondsSinceEpoch(microsSinceEpoch.toInt());
}

enum ChatSendStatus { pending, sent, failed }

class ChatSendEntry {
  final ChatSendStatus status;
  final Message message;

  const ChatSendEntry({required this.status, required this.message});

  ChatSendEntry copyWith({ChatSendStatus? status}) =>
      ChatSendEntry(status: status ?? this.status, message: message);
}

class ChatSendStatusNotifier extends StateNotifier<Map<String, ChatSendEntry>> {
  StreamSubscription<MutationSyncResult>? _resultSub;

  ChatSendStatusNotifier() : super(const {});

  @override
  void dispose() {
    _resultSub?.cancel();
    super.dispose();
  }

  void attachClient(SpacetimeDbClient? client) {
    _resultSub?.cancel();
    _resultSub = client?.onMutationSyncResult.listen(_onResult);
    if (client != null) _seedFromPendingQueue(client);
  }

  void markPending(Message message) {
    debugLogger.chat('sendStatus pending', 'id=${message.id}');
    state = {
      ...state,
      message.id: ChatSendEntry(
        status: ChatSendStatus.pending,
        message: message,
      ),
    };
  }

  void clear(String id) {
    if (!state.containsKey(id)) return;
    debugLogger.chat('sendStatus clear', 'id=$id');
    final next = Map<String, ChatSendEntry>.from(state)..remove(id);
    state = next;
  }

  /// Rebuild pending (clock) status from the SDK's durable mutation queue.
  /// The in-memory status map dies on app kill, but the queued messages
  /// survive in `pending_mutations.jsonl` — so on (re)attach, mark every
  /// still-queued pushMessage as pending again. Without this, a message sent
  /// offline then killed reopens with no clock and looks (wrongly) sent.
  Future<void> _seedFromPendingQueue(SpacetimeDbClient client) async {
    if (!client.hasOfflineStorage) return;
    try {
      final pending = await client.subscriptions.getPendingMutations();
      var changed = false;
      final next = Map<String, ChatSendEntry>.from(state);
      for (final mutation in pending) {
        if (mutation.reducerName != pushMessageDef.name) continue;
        final insert = mutation.optimisticChanges?.firstWhereOrNull(
          (c) => c.type == OptimisticChangeType.insert && c.newRowJson != null,
        );
        final row = insert?.newRowJson;
        if (row == null) continue;
        final id = row['id'];
        if (id is! String || next.containsKey(id)) continue;
        try {
          next[id] = ChatSendEntry(
            status: ChatSendStatus.pending,
            message: Message.fromJson(row),
          );
          changed = true;
        } catch (_) {}
      }
      if (changed) {
        debugLogger.chat('sendStatus seed',
            'restored ${next.length - state.length} pending from durable queue');
        state = next;
      }
    } catch (e) {
      debugLogger.chatError('sendStatus seed failed', '$e');
    }
  }

  void _onResult(MutationSyncResult result) {
    if (result.reducerName != pushMessageDef.name) return;
    debugLogger.chat('sendStatus result',
        'success=${result.success} reqId=${result.requestId}');
    if (result.success) {
      _reconcileSent();
      return;
    }
    final changes = result.optimisticChanges;
    if (changes == null) return;
    final next = Map<String, ChatSendEntry>.from(state);
    var changed = false;
    for (final change in changes) {
      final row = change.newRowJson;
      final id = row?['id'];
      if (id is! String) continue;
      final existing = next[id];
      final message = existing?.message ?? Message.fromJson(row!);
      next[id] = ChatSendEntry(status: ChatSendStatus.failed, message: message);
      debugLogger.chatError('sendStatus failed', 'id=$id err=${result.error}');
      changed = true;
    }
    if (changed) state = next;
  }

  void _reconcileSent() {
    Map<String, ChatSendEntry>? next;
    for (final entry in state.entries) {
      if (entry.value.status == ChatSendStatus.pending) {
        next ??= Map<String, ChatSendEntry>.from(state);
        debugLogger.chat('sendStatus sent', 'id=${entry.key}');
        next[entry.key] = entry.value.copyWith(status: ChatSendStatus.sent);
      }
    }
    if (next != null) state = next;
  }
}

final chatSendStatusProvider =
    StateNotifierProvider<ChatSendStatusNotifier, Map<String, ChatSendEntry>>(
        (ref) {
  final notifier = ChatSendStatusNotifier();
  notifier.attachClient(ref.read(spacetimeClientProvider));
  ref.listen<SpacetimeDbClient?>(spacetimeClientProvider, (prev, next) {
    debugLogger.chat('chatSendStatus', 'client changed -> reattach result sub');
    notifier.attachClient(next);
  });
  return notifier;
});

int _localSendSeq = 0;

String _mintMessageId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  _localSendSeq++;
  return 'u$ms-$_localSendSeq';
}

Future<void> sendChatMessage(
  WidgetRef ref, {
  required String sessionId,
  required String text,
}) async {
  final client = ref.read(spacetimeClientProvider);
  if (client == null) {
    debugLogger.chatError('sendChatMessage aborted', 'client=null');
    return;
  }
  ref.read(recentSessionsProvider.notifier).markUsed(sessionId);
  final id = _mintMessageId();
  debugLogger.chat(
    'sendChatMessage',
    'id=$id session=$sessionId textLen=${text.length}',
  );
  final message = Message(
    id: id,
    sessionId: sessionId,
    role: 'user',
    text: text,
    source: 'flutter',
    createdAt: Int64(DateTime.now().microsecondsSinceEpoch),
  );
  ref.read(chatSendStatusProvider.notifier).markPending(message);
  try {
    await client.reducers.pushMessage(
      id: id,
      sessionId: sessionId,
      role: 'user',
      text: text,
      source: 'flutter',
      optimisticChanges: [OptimisticChange.insertRow(client.message, message)],
    );
    debugLogger.chat('sendChatMessage ok', 'id=$id');
    _probeEcho(client, id, 'msg');
  } catch (e, st) {
    debugLogger.chatError('sendChatMessage threw', 'id=$id err=$e\n$st');
    rethrow;
  }
}

void _probeEcho(SpacetimeDbClient client, String id, String kind) {
  Future.delayed(const Duration(seconds: 2), () {
    final found = client.message.rows.value.any((m) => m.id == id);
    if (found) {
      debugLogger.chat('echo ok', 'kind=$kind id=$id');
    } else {
      debugLogger.chatError(
        'echo MISSING after 2s',
        'kind=$kind id=$id — server reducer succeeded but no server broadcast arrived; '
            'socket may be silently dead (iOS backgrounded read-half)',
      );
    }
  });
}

Future<void> sendChatImage(
  WidgetRef ref, {
  required String sessionId,
  required String caption,
  required Uint8List pngBytes,
}) async {
  final client = ref.read(spacetimeClientProvider);
  if (client == null) {
    debugLogger.chatError('sendChatImage aborted', 'client=null');
    return;
  }
  final id = _mintMessageId();
  debugLogger.chat(
    'sendChatImage',
    'id=$id session=$sessionId bytes=${pngBytes.length} captionLen=${caption.length}',
  );
  try {
    await client.reducers.pushImage(
      id: id,
      sessionId: sessionId,
      caption: caption,
      bytes: pngBytes,
    );
    debugLogger.chat('sendChatImage ok', 'id=$id');
    _probeEcho(client, id, 'img');
  } catch (e, st) {
    debugLogger.chatError('sendChatImage threw', 'id=$id err=$e\n$st');
    rethrow;
  }
}

Future<void> respondToPermission(
  WidgetRef ref, {
  required String requestId,
  required bool allow,
}) async {
  final client = ref.read(spacetimeClientProvider);
  if (client == null) return;
  await client.reducers.resolvePermission(
    id: requestId,
    status: allow ? 'allow' : 'deny',
  );
}

/// Answers an AskUserQuestion. [labels] holds the selected option label(s) —
/// one for single-select, one or more for multi-select. Encoded as JSON so the
/// space-channel bridge can inject it back into the session.
Future<void> respondToQuestion(
  WidgetRef ref, {
  required String requestId,
  required List<String> labels,
}) async {
  final client = ref.read(spacetimeClientProvider);
  if (client == null) return;
  await client.reducers.respondToQuestion(
    id: requestId,
    response: jsonEncode(labels),
  );
}
