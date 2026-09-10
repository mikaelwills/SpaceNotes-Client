import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

class SnToggle extends StatelessWidget {
  const SnToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? SpaceNotesTheme.accent : SpaceNotesTheme.dim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          value ? '[on]' : '[off]',
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 12,
            color: color,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
