import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../blocs/worker/worker_bloc.dart';
import '../blocs/worker/worker_state.dart';
import '../theme/spacenotes_theme.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late final WorkerBloc _workerBloc;

  @override
  void initState() {
    super.initState();
    _workerBloc = GetIt.I<WorkerBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkerBloc, WorkerState>(
      bloc: _workerBloc,
      builder: (context, state) {
        final workers = state.workers.values.toList()
          ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: workers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        return _WorkerTile(worker: workers[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _WorkerTile extends StatelessWidget {
  final WorkerInfo worker;

  const _WorkerTile({required this.worker});

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
                      'connected ${_timeAgo(worker.connectedAt)} · active ${_timeAgo(worker.lastActivity)}',
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
          if (worker.project.isNotEmpty || worker.task.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (worker.project.isNotEmpty)
                  _InfoChip(label: 'project', value: worker.project),
                if (worker.task.isNotEmpty)
                  _InfoChip(label: 'task', value: worker.task),
              ],
            ),
          ],
          if (worker.recentToolEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceNotesTheme.inputSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: worker.recentToolEvents
                    .take(5)
                    .map(
                      (event) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Text(
                              event.toolName,
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
                                event.inputSummary,
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
    );
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
