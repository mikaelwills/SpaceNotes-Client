import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/session.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';

class SessionDashboard extends ConsumerWidget {
  const SessionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Text(
                'Sessions',
                style: TextStyle(
                  color: SpaceNotesTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${sessions.length}',
                  style: const TextStyle(
                    color: SpaceNotesTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.memory,
                          size: 48,
                          color: SpaceNotesTheme.textSecondary
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'No sessions connected',
                        style: TextStyle(
                          color: SpaceNotesTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final base = _baseName(session.id);
                    final baseCount =
                        sessions.where((s) => _baseName(s.id) == base).length;
                    return _SessionTile(
                      session: session,
                      showHost: baseCount > 1,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _baseName(String sessionKey) {
  final idx = sessionKey.indexOf('@');
  return idx < 0 ? sessionKey : sessionKey.substring(0, idx);
}

String _hostPart(String sessionKey) {
  final idx = sessionKey.indexOf('@');
  return idx < 0 ? '' : sessionKey.substring(idx + 1);
}

class _SessionTile extends ConsumerWidget {
  final Session session;
  final bool showHost;

  const _SessionTile({required this.session, this.showHost = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(sessionActivityProvider(session.id));
    final isActive = activity != null && activity.state != 'idle';

    return InkWell(
      onTap: () =>
          context.push('/notes/sessions/${Uri.encodeComponent(session.id)}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? SpaceNotesTheme.primary.withValues(alpha: 0.15)
                        : SpaceNotesTheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isActive
                      ? const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: SpaceNotesTheme.primary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.terminal_outlined,
                          size: 18,
                          color: SpaceNotesTheme.secondary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              _baseName(session.id),
                              style: const TextStyle(
                                fontFamily: 'FiraCode',
                                fontSize: 13,
                                color: SpaceNotesTheme.text,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showHost && _hostPart(session.id).isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              _hostPart(session.id),
                              style: const TextStyle(
                                fontFamily: 'FiraCode',
                                fontSize: 10,
                                color: SpaceNotesTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'registered ${_timeAgo(session.createdAt)} · last seen ${_timeAgo(session.lastSeen)}',
                        style: const TextStyle(
                          color: SpaceNotesTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (activity != null && activity.state != 'idle') ...[
              const SizedBox(height: 8),
              Text(
                activity.state == 'tool_use' ? 'tool…' : 'thinking…',
                style: const TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 10,
                  color: SpaceNotesTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(Int64 ts) {
    final dt = timestampToDateTime(ts);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
