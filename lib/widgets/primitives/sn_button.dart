import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

enum SnButtonVariant { filled, outline, ghost }

class SnButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SnButtonVariant variant;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  const SnButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SnButtonVariant.outline,
    this.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? SpaceNotesTheme.accent;
    final isFilled = variant == SnButtonVariant.filled;
    final isGhost = variant == SnButtonVariant.ghost;
    final isAccentTinted = variant != SnButtonVariant.filled && accent != null;

    final Color borderColor = isFilled
        ? color
        : (isAccentTinted && !isGhost ? color : SpaceNotesTheme.hairlineStrong);
    final Color textColor = isFilled
        ? SpaceNotesTheme.bg
        : (isAccentTinted ? color : SpaceNotesTheme.fg);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            border: isGhost
                ? null
                : Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class SnIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? tooltip;
  final double size;

  const SnIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.active = false,
    this.tooltip,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  size: 14,
                  color:
                      active ? SpaceNotesTheme.accent : SpaceNotesTheme.muted,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color:
                        active ? SpaceNotesTheme.accent : SpaceNotesTheme.muted,
                  ),
                  child: icon,
                ),
              ),
              if (active)
                Positioned(
                  bottom: 2,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 1,
                    color: SpaceNotesTheme.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip ?? '', child: btn);
    }
    return btn;
  }
}
