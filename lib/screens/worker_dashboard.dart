import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../theme/spacenotes_theme.dart';

class WorkerInfo {
  final String session;
  final String? project;
  final String? task;
  final DateTime lastSeen;
  final String? lastMessage;

  const WorkerInfo({
    required this.session,
    this.project,
    this.task,
    required this.lastSeen,
    this.lastMessage,
  });
}

final workerListProvider = Provider<List<WorkerInfo>>((ref) {
  final chatBloc = GetIt.I<ChatBloc>();
  final state = chatBloc.state;

  if (state is! ChatReady) return [];

  final workers = <String, WorkerInfo>{};

  for (final msg in state.messages) {
    if (msg.sourceType == 'worker' && msg.session != null) {
      final text = msg.parts.isNotEmpty ? msg.parts.first.content : null;
      final preview = text != null && text.length > 80
          ? '${text.substring(0, 80)}...'
          : text;

      workers[msg.session!] = WorkerInfo(
        session: msg.session!,
        project: msg.project,
        task: msg.task,
        lastSeen: msg.created,
        lastMessage: preview,
      );
    }
  }

  final list = workers.values.toList();
  list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  return list;
});

class WorkerDashboard extends ConsumerStatefulWidget {
  const WorkerDashboard({super.key});

  @override
  ConsumerState<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends ConsumerState<WorkerDashboard> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    final chatBloc = GetIt.I<ChatBloc>();
    _subscription = chatBloc.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workers = ref.watch(workerListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Text(
                'Workers',
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
                  '${workers.length}',
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
          child: workers.isEmpty
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
                        'No workers connected',
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
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    return _WorkerTile(worker: workers[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class _WorkerTile extends StatelessWidget {
  final WorkerInfo worker;

  const _WorkerTile({required this.worker});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: SpaceNotesTheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
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
                  color: SpaceNotesTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
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
                      worker.session,
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
                      _timeAgo(worker.lastSeen),
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
          if (worker.project != null || worker.task != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (worker.project != null)
                  _InfoChip(label: 'project', value: worker.project!),
                if (worker.task != null)
                  _InfoChip(label: 'task', value: worker.task!),
              ],
            ),
          ],
          if (worker.lastMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              worker.lastMessage!,
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
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
