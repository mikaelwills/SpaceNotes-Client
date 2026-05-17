import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

enum DashStatusTone { neutral, success, warning, error, info }

class DashStatusBadge extends StatelessWidget {
  final String label;
  final DashStatusTone tone;

  const DashStatusBadge({
    super.key,
    required this.label,
    this.tone = DashStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      DashStatusTone.success => SpaceNotesTheme.accent,
      DashStatusTone.warning => SpaceNotesTheme.warning,
      DashStatusTone.error => SpaceNotesTheme.offline,
      DashStatusTone.info => SpaceNotesTheme.accent2,
      DashStatusTone.neutral => SpaceNotesTheme.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 9,
          color: color,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class DashTagChip extends StatelessWidget {
  final String label;
  final Color? color;

  const DashTagChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? SpaceNotesTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: SpaceNotesTheme.hairlineStrong, width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: c,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}
