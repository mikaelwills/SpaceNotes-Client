import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

class SnMicroLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final double letterSpacing;

  const SnMicroLabel(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 10,
    this.letterSpacing = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: SpaceNotesTheme.fontMono,
        fontSize: fontSize,
        color: color ?? SpaceNotesTheme.muted,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class SnUiText extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final double letterSpacing;
  final FontWeight weight;
  final TextOverflow? overflow;
  final int? maxLines;

  const SnUiText(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 12,
    this.letterSpacing = 0.3,
    this.weight = FontWeight.w400,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: overflow,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: SpaceNotesTheme.fontMono,
        fontSize: fontSize,
        color: color ?? SpaceNotesTheme.fg,
        letterSpacing: letterSpacing,
        fontWeight: weight,
      ),
    );
  }
}
