import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class DownloadProgress extends StatelessWidget {
  const DownloadProgress({
    super.key,
    required this.progress,
    required this.receivedBytes,
    required this.startedAt,
  });

  final double progress;
  final int receivedBytes;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
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
              Text('${(progress * 100).toStringAsFixed(0)}%',
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

  String get _speedLabel {
    if (startedAt == null || receivedBytes <= 0) return '';
    final elapsed = DateTime.now().difference(startedAt!).inMilliseconds;
    if (elapsed <= 0) return '';
    final bytesPerSecond = receivedBytes / (elapsed / 1000);
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
