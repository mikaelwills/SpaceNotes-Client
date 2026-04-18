import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

class SnHairline extends StatelessWidget {
  final Axis axis;
  final bool strong;

  const SnHairline(
      {super.key, this.axis = Axis.horizontal, this.strong = false});

  const SnHairline.vertical({super.key, this.strong = false})
      : axis = Axis.vertical;

  @override
  Widget build(BuildContext context) {
    final color =
        strong ? SpaceNotesTheme.hairlineStrong : SpaceNotesTheme.hairline;
    if (axis == Axis.horizontal) {
      return Container(height: 1, color: color);
    }
    return Container(width: 1, color: color);
  }
}
