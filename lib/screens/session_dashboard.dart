import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../theme/spacenotes_theme.dart';

class SessionDashboard extends StatefulWidget {
  const SessionDashboard({super.key});

  @override
  State<SessionDashboard> createState() => _SessionDashboardState();
}

class _SessionDashboardState extends State<SessionDashboard> {
  late final ChatBloc _chatBloc;

  @override
  void initState() {
    super.initState();
    _chatBloc = GetIt.I<ChatBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      bloc: _chatBloc,
      builder: (context, state) {
        final sessions = state is ChatReady
            ? (state.sessions.values.toList()
              ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity)))
            : <SessionInfo>[];

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _SessionTile(sessionInfo: sessions[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionInfo sessionInfo;

  const _SessionTile({required this.sessionInfo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/notes/sessions/${Uri.encodeComponent(sessionInfo.session)}'),
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
                  color: sessionInfo.activityState != SessionActivityState.idle
                      ? SpaceNotesTheme.primary.withValues(alpha: 0.15)
                      : SpaceNotesTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: sessionInfo.activityState != SessionActivityState.idle
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: SpaceNotesTheme.primary.withValues(alpha: 0.8),
                            ),
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
                    Text(
                      sessionInfo.session,
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 13,
                        color: SpaceNotesTheme.text,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'connected ${_timeAgo(sessionInfo.connectedAt)} · active ${_timeAgo(sessionInfo.lastActivity)}',
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
          if (sessionInfo.task.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InfoChip(label: 'task', value: sessionInfo.task),
              ],
            ),
          ],
          if (sessionInfo.recentToolEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceNotesTheme.inputSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sessionInfo.recentToolEvents
                    .take(5)
                    .map(
                      (event) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Text(
                              event.tool,
                              style: const TextStyle(
                                fontFamily: 'FiraCode',
                                fontSize: 10,
                                color: SpaceNotesTheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatToolInput(event.input),
                                style: const TextStyle(
                                  fontFamily: 'FiraCode',
                                  fontSize: 10,
                                  color: SpaceNotesTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }

  String _formatToolInput(Map<String, dynamic> input) {
    final command = input['command'];
    if (command is String && command.isNotEmpty) return command;
    final path = input['file_path'] ?? input['path'];
    if (path is String && path.isNotEmpty) return path;
    final pattern = input['pattern'];
    if (pattern is String && pattern.isNotEmpty) return pattern;
    final query = input['query'];
    if (query is String && query.isNotEmpty) return query;
    if (input.isEmpty) return '';
    final first = input.values.first;
    return first is String ? first : first.toString();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 10,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 10,
              color: SpaceNotesTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
