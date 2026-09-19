import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class DownloadingBadge extends StatelessWidget {
  const DownloadingBadge({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpaceNotesTheme.hairlineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress,
              color: SpaceNotesTheme.accent,
              backgroundColor: SpaceNotesTheme.hairline,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(color: SpaceNotesTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
