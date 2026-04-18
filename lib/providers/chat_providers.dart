import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';
import '../generated/client.dart';
import '../generated/message.dart';
import '../generated/permission_request.dart';
import '../generated/session.dart';
import '../generated/session_activity.dart';
import '../generated/tool_event.dart';
import 'notes_providers.dart';

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

const String defaultTargetSession = 'note-assistant';

final sessionsProvider = Provider<List<Session>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.session.rows);
  final sorted = rows.toList()
    ..sort(
        (a, b) => a.baseName.toLowerCase().compareTo(b.baseName.toLowerCase()));
  return sorted;
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

/// Manual override. Null = auto-pick from sessions list.
final targetSessionOverrideProvider = StateProvider<String?>((ref) => null);

/// Session id used by the main chat. Auto-picks the first session whose
/// baseName matches [defaultTargetSession]; falls back to the bare default.
final targetSessionProvider = Provider<String>((ref) {
  final override = ref.watch(targetSessionOverrideProvider);
  if (override != null) return override;
  final sessions = ref.watch(sessionsProvider);
  for (final s in sessions) {
    if (s.baseName == defaultTargetSession) return s.id;
  }
  if (sessions.isNotEmpty) return sessions.first.id;
  return defaultTargetSession;
});

final _chatIndexProvider = Provider<_ChatIndex?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  final index = _ChatIndex(client);
  ref.onDispose(index.dispose);
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
  return List<ChatItem>.unmodifiable(bucket.items);
});

/// Per-session bucket holding the merged sorted timeline.
class _SessionBucket extends ChangeNotifier {
  final List<ChatItem> items = [];

  void add(ChatItem item) {
    final idx = _insertionIndex(item.timestamp);
    items.insert(idx, item);
    notifyListeners();
  }

  void replace(String id, ChatItem next) {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx == -1) {
      add(next);
      return;
    }
    if (items[idx].timestamp == next.timestamp) {
      items[idx] = next;
    } else {
      items.removeAt(idx);
      final reIdx = _insertionIndex(next.timestamp);
      items.insert(reIdx, next);
    }
    notifyListeners();
  }

  void removeById(String id) {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    items.removeAt(idx);
    notifyListeners();
  }

  int _insertionIndex(Int64 ts) {
    var lo = 0;
    var hi = items.length;
    while (lo < hi) {
      final mid = (lo + hi) >>> 1;
      if (items[mid].timestamp.compareTo(ts) <= 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// Maintains per-session timelines incrementally from SDK events. Listens to
/// message/tool_event/permission_request insert/update/delete streams once;
/// routes each row to its session bucket. Buckets are created lazily.
class _ChatIndex {
  final SpacetimeDbClient client;
  final Map<String, _SessionBucket> _buckets = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  _ChatIndex(this.client) {
    _hydrate();
    _wireListeners();
  }

  _SessionBucket bucketFor(String sessionId) =>
      _buckets.putIfAbsent(sessionId, _SessionBucket.new);

  void _hydrate() {
    for (final m in client.message.rows.value) {
      bucketFor(m.sessionId).add(ChatMessageItem(m));
    }
    for (final t in client.toolEvent.rows.value) {
      bucketFor(t.sessionId).add(ChatToolItem(t));
    }
    for (final p in client.permissionRequest.rows.value) {
      if (p.status == 'pending') {
        bucketFor(p.sessionId).add(ChatPermissionItem(p));
      }
    }
  }

  void _wireListeners() {
    _subs.add(client.message.onInsert.listen((e) {
      bucketFor(e.row.sessionId).add(ChatMessageItem(e.row));
    }));
    _subs.add(client.message.onUpdate.listen((e) {
      final bucket = bucketFor(e.newRow.sessionId);
      bucket.replace('msg:${e.newRow.id}', ChatMessageItem(e.newRow));
    }));
    _subs.add(client.message.onDelete.listen((e) {
      bucketFor(e.row.sessionId).removeById('msg:${e.row.id}');
    }));

    _subs.add(client.toolEvent.onInsert.listen((e) {
      bucketFor(e.row.sessionId).add(ChatToolItem(e.row));
    }));
    _subs.add(client.toolEvent.onUpdate.listen((e) {
      final bucket = bucketFor(e.newRow.sessionId);
      bucket.replace('tool:${e.newRow.id}', ChatToolItem(e.newRow));
    }));
    _subs.add(client.toolEvent.onDelete.listen((e) {
      bucketFor(e.row.sessionId).removeById('tool:${e.row.id}');
    }));

    _subs.add(client.permissionRequest.onInsert.listen((e) {
      if (e.row.status != 'pending') return;
      bucketFor(e.row.sessionId).add(ChatPermissionItem(e.row));
    }));
    _subs.add(client.permissionRequest.onUpdate.listen((e) {
      final id = 'perm:${e.newRow.id}';
      final bucket = bucketFor(e.newRow.sessionId);
      if (e.newRow.status != 'pending') {
        bucket.removeById(id);
      } else {
        bucket.replace(id, ChatPermissionItem(e.newRow));
      }
    }));
    _subs.add(client.permissionRequest.onDelete.listen((e) {
      bucketFor(e.row.sessionId).removeById('perm:${e.row.id}');
    }));
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    for (final b in _buckets.values) {
      b.dispose();
    }
    _buckets.clear();
  }
}

DateTime timestampToDateTime(Int64 microsSinceEpoch) {
  return DateTime.fromMicrosecondsSinceEpoch(microsSinceEpoch.toInt());
}

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
  if (client == null) return;
  await client.reducers.pushMessage(
    id: _mintMessageId(),
    sessionId: sessionId,
    role: 'user',
    text: text,
    source: 'flutter',
  );
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
