import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

enum SnToolStatus { running, done, denied, ask }

class SnToolLine extends StatefulWidget {
  final String label;
  final SnToolStatus status;

  const SnToolLine({
    super.key,
    required this.label,
    this.status = SnToolStatus.done,
  });

  @override
  State<SnToolLine> createState() => _SnToolLineState();
}

class _SnToolLineState extends State<SnToolLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.status == SnToolStatus.running) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SnToolLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SnToolStatus.running && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.status != SnToolStatus.running && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final opacity = widget.status == SnToolStatus.running
            ? 1.0 - (_pulse.value * 0.65)
            : 1.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Opacity(
              opacity: opacity,
              child: Text(
                '›',
                style: TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 11,
                  color: _color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 11,
                  color: SpaceNotesTheme.muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color get _color => switch (widget.status) {
        SnToolStatus.running => SpaceNotesTheme.accent2,
        SnToolStatus.done => SpaceNotesTheme.accent2,
        SnToolStatus.denied => SpaceNotesTheme.offline,
        SnToolStatus.ask => SpaceNotesTheme.accent2,
      };
}
