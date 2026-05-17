import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

enum DashTrend { up, down, flat }

class DashKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final DashTrend? trend;
  final String? unit;

  const DashKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.trend,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return SnCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SnMicroLabel(label),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 11,
                      color: SpaceNotesTheme.dim,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _TrendChip(text: delta!, trend: trend ?? DashTrend.flat),
            ),
          ],
        ],
      ),
    );
  }
}

class DashStatBlock extends StatelessWidget {
  final String label;
  final String value;

  const DashStatBlock({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SnMicroLabel(label),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontSans,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: SpaceNotesTheme.fg,
            letterSpacing: -0.2,
            height: 1.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class DashMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final DashTrend? trend;
  final bool last;

  const DashMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.trend,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last ? Colors.transparent : SpaceNotesTheme.hairline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.muted,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 13,
              color: SpaceNotesTheme.fg,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(width: 10),
            _TrendChip(text: delta!, trend: trend ?? DashTrend.flat, dense: true),
          ],
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String text;
  final DashTrend trend;
  final bool dense;

  const _TrendChip({required this.text, required this.trend, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (trend) {
      DashTrend.up => SpaceNotesTheme.accent,
      DashTrend.down => SpaceNotesTheme.offline,
      DashTrend.flat => SpaceNotesTheme.muted,
    };
    final arrow = switch (trend) {
      DashTrend.up => '↑',
      DashTrend.down => '↓',
      DashTrend.flat => '→',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arrow,
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: dense ? 9 : 10,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: dense ? 10 : 11,
              color: color,
              letterSpacing: 0.3,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
