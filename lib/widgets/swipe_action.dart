import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class SwipeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double width;
  final VoidCallback onTap;

  const SwipeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border(
              left: BorderSide(
                color: color.withValues(alpha: 0.35),
                width: 1,
              ),
              bottom: const BorderSide(
                color: SpaceNotesTheme.hairline,
                width: 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
