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
    return GestureDetector(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 9,
                color: color,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
