import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/upload_progress_providers.dart';
import '../theme/spacenotes_theme.dart';

/// Sleek line under the nav, visible on any screen while a batch upload is
/// running: a cyan bar filling left-to-right plus a "n/total" counter that
/// increments as each file finishes.
class UploadProgressBar extends ConsumerWidget {
  const UploadProgressBar({super.key});

  static const bool _debugAlwaysShow = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(uploadBatchProvider);

    if (!_debugAlwaysShow && (batch.total == 0 || !batch.isActive)) {
      return const SizedBox.shrink();
    }

    final finished = batch.completed + batch.failed;
    final overallProgress = batch.total == 0
        ? (_debugAlwaysShow ? 0.4 : 0.0)
        : (finished + batch.currentProgress) / batch.total;
    final speedLabel = _speedLabel(batch.activeJob);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 3,
          color: SpaceNotesTheme.hairline,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overallProgress.clamp(0, 1)),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                speedLabel,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 9,
                  color: SpaceNotesTheme.muted,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '$finished/${batch.total}',
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 9,
                  color: SpaceNotesTheme.muted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _speedLabel(UploadJob? job) {
    if (job == null || job.sentBytes <= 0) return '';
    final elapsed = DateTime.now().difference(job.startedAt).inMilliseconds;
    if (elapsed <= 0) return '';
    final bytesPerSecond = job.sentBytes / (elapsed / 1000);
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
