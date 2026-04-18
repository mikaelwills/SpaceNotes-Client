import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/message.dart';
import '../generated/permission_request.dart';
import '../generated/session.dart';
import '../generated/session_activity.dart';
import '../generated/tool_event.dart';
import 'notes_providers.dart';

sealed class ChatItem {
  Int64 get timestamp;
}

class ChatMessageItem extends ChatItem {
  final Message message;
  ChatMessageItem(this.message);
  @override
  Int64 get timestamp => message.createdAt;
}

class ChatToolItem extends ChatItem {
  final ToolEvent event;
  ChatToolItem(this.event);
  @override
  Int64 get timestamp => event.startedAt;
}

class ChatPermissionItem extends ChatItem {
  final PermissionRequest request;
  ChatPermissionItem(this.request);
  @override
  Int64 get timestamp => request.createdAt;
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

final messagesBySessionProvider =
    Provider.family<List<Message>, String>((ref, sessionId) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.message.rows);
  final filtered = rows.where((m) => m.sessionId == sessionId).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  debugPrint(
      '[CHAT] messagesBySession($sessionId) → ${filtered.length} messages '
      '(${filtered.map((m) => '${m.role}:${m.source}').join(',')})');
  return filtered;
});

final allMessagesProvider = Provider<List<Message>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.message.rows);
  final sorted = rows.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted;
});

final toolEventsBySessionProvider =
    Provider.family<List<ToolEvent>, String>((ref, sessionId) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.toolEvent.rows);
  final filtered = rows.where((t) => t.sessionId == sessionId).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return filtered;
});

final pendingPermissionsProvider = Provider<List<PermissionRequest>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.permissionRequest.rows);
  final pending = rows.where((p) => p.status == 'pending').toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return pending;
});

final permissionByIdProvider =
    Provider.family<PermissionRequest?, String>((ref, id) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.permissionRequest.rowNotifier(id));
});

/// Manual override. Null = auto-pick from sessions list (see
/// [resolvedTargetSessionProvider]).
final targetSessionOverrideProvider = StateProvider<String?>((ref) => null);

/// The session id to send chat messages to. Auto-picks the first session
/// whose baseName matches [defaultTargetSession]; falls back to the bare
/// default if no matching row exists yet (pre-connect).
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

final chatTimelineBySessionProvider =
    Provider.family<List<ChatItem>, String>((ref, sessionId) {
  final messages = ref.watch(messagesBySessionProvider(sessionId));
  final toolEvents = ref.watch(toolEventsBySessionProvider(sessionId));
  final permissions = ref
      .watch(pendingPermissionsProvider)
      .where((p) => p.sessionId == sessionId)
      .toList();

  final items = <ChatItem>[
    ...messages.map(ChatMessageItem.new),
    ...toolEvents.map(ChatToolItem.new),
    ...permissions.map(ChatPermissionItem.new),
  ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return items;
});

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
  if (client == null) {
    debugPrint('[CHAT] sendChatMessage aborted — client is null');
    return;
  }
  final id = _mintMessageId();
  debugPrint(
      '[CHAT] → pushMessage id=$id session=$sessionId len=${text.length} "${text.length > 60 ? '${text.substring(0, 60)}…' : text}"');
  try {
    await client.reducers.pushMessage(
      id: id,
      sessionId: sessionId,
      role: 'user',
      text: text,
      source: 'flutter',
    );
    debugPrint('[CHAT] ✓ pushMessage reducer dispatched id=$id');
  } catch (e, stack) {
    debugPrint('[CHAT] ✗ pushMessage FAILED id=$id: $e');
    debugPrint('$stack');
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
