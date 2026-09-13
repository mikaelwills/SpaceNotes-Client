import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

/// Progress for one download attempt.
///
/// On a resume the first reported value is whatever is already on disk, not
/// zero. That byte count is a starting position rather than transfer, so the
/// widget remembers it and excludes it from the speed reading — otherwise a
/// resumed 40MB file divided by a fraction of a second reads as hundreds of
/// MB/s before a single new byte has arrived.
class DownloadProgress extends StatefulWidget {
  const DownloadProgress({
    super.key,
    required this.progress,
    required this.receivedBytes,
    required this.startedAt,
    this.totalBytes = 0,
  });

  final double progress;
  final int receivedBytes;
  final DateTime? startedAt;
  final int totalBytes;

  @override
  State<DownloadProgress> createState() => _DownloadProgressState();
}

class _DownloadProgressState extends State<DownloadProgress> {
  int? _resumedFrom;

  @override
  Widget build(BuildContext context) {
    _resumedFrom ??= widget.receivedBytes;
    final progress = widget.progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: SpaceNotesTheme.hairline),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0, 1)),
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
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_speedLabel,
                  style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      color: SpaceNotesTheme.muted,
                      fontSize: 11)),
              Text(_transferredLabel,
                  style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      color: SpaceNotesTheme.muted,
                      fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  String get _transferredLabel {
    final total = widget.totalBytes;
    if (total <= 0) return '${(widget.progress * 100).toStringAsFixed(0)}%';
    const megabyte = 1024 * 1024;
    if (total < megabyte) {
      final receivedKb = widget.receivedBytes / 1024;
      return '${receivedKb.toStringAsFixed(0)}/${(total / 1024).toStringAsFixed(0)}KB';
    }
    final receivedMb = widget.receivedBytes / megabyte;
    final totalMb = total / megabyte;
    final receivedText = receivedMb >= 10
        ? receivedMb.toStringAsFixed(0)
        : receivedMb.toStringAsFixed(1);
    return '$receivedText/${totalMb.toStringAsFixed(0)}MB';
  }

  String get _speedLabel {
    final startedAt = widget.startedAt;
    if (startedAt == null) return '';
    final movedThisAttempt = widget.receivedBytes - (_resumedFrom ?? 0);
    if (movedThisAttempt <= 0) return '';
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsed <= 0) return '';
    final bytesPerSecond = movedThisAttempt / (elapsed / 1000);
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
