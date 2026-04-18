import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

class SnCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final bool border;
  final VoidCallback? onTap;

  const SnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(13, 12, 13, 14),
    this.background,
    this.border = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      decoration: BoxDecoration(
        color: background ?? SpaceNotesTheme.card,
        border: border
            ? Border.all(color: SpaceNotesTheme.hairline, width: 1)
            : null,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: surface),
    );
  }
}
