import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/download_queue_provider.dart';
import '../theme/spacenotes_theme.dart';

class DownloadProgressBar extends ConsumerWidget {
  const DownloadProgressBar({super.key});

  static const _label = TextStyle(
    fontFamily: SpaceNotesTheme.fontMono,
    fontSize: 9,
    color: SpaceNotesTheme.muted,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);

    if (queue.hasSummary) return _Summary(queue: queue);
    if (!queue.isActive) return const SizedBox.shrink();

    final current = queue.current;
    final finished = queue.done + queue.failed.length;
    final overall = (finished + (current?.progress ?? 0)) / queue.total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 3,
          color: SpaceNotesTheme.hairline,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overall.clamp(0, 1)),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (context, value, child) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: const ColoredBox(color: SpaceNotesTheme.accent),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  current == null
                      ? 'downloading'
                      : '${current.fileName} ${(current.progress * 100).round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _label,
                ),
              ),
              const SizedBox(width: 8),
              Text('$finished/${queue.total}', style: _label),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.queue});

  final DownloadQueueState queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = queue.failed;
    final reason = queue.stoppedReason;
    final names = failed.map((j) => j.fileName).join(', ');
    final text = [
      if (reason != null) reason.toLowerCase(),
      if (failed.isNotEmpty) '${failed.length} failed: $names',
    ].join(' · ');

    return GestureDetector(
      key: const ValueKey('download-summary'),
      behavior: HitTestBehavior.opaque,
      onTap: ref.read(downloadQueueProvider.notifier).dismiss,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DownloadProgressBar._label.copyWith(
                  color: SpaceNotesTheme.offline,
                ),
              ),
            ),
            const Icon(Icons.close, size: 11, color: SpaceNotesTheme.dim),
          ],
        ),
      ),
    );
  }
}
