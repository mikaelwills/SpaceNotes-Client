import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import 'sn_micro_label.dart';

class SnStatusLine extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool divider;

  const SnStatusLine({
    super.key,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: divider
            ? const Border(
                bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.muted,
              letterSpacing: 0.5,
            ),
            child: leading ?? const SizedBox.shrink(),
          ),
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.muted,
              letterSpacing: 0.5,
            ),
            child: trailing ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class SnStatusDiamond extends StatelessWidget {
  final String label;
  final String? trail;
  const SnStatusDiamond(this.label, {super.key, this.trail});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('◆',
            style: TextStyle(
              color: SpaceNotesTheme.accent,
              fontSize: 10,
              fontFamily: SpaceNotesTheme.fontMono,
            )),
        const SizedBox(width: 14),
        SnUiText(label, color: SpaceNotesTheme.muted, fontSize: 10),
        if (trail != null) ...[
          const SizedBox(width: 14),
          SnUiText(trail!, color: SpaceNotesTheme.dim, fontSize: 10),
        ],
      ],
    );
  }
}
