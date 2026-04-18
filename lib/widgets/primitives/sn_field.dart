import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

class SnField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final double height;
  final double radius;
  final Color background;
  final Color borderColor;

  const SnField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.height = 44,
    this.radius = SpaceNotesTheme.radiusDock,
    this.background = SpaceNotesTheme.bgAlt,
    this.borderColor = SpaceNotesTheme.hairlineStrong,
  });

  @override
  Widget build(BuildContext context) {
    final autoGrow = expands || maxLines == null || (maxLines ?? 1) > 1;
    return Container(
      height: autoGrow ? null : height,
      constraints: autoGrow ? BoxConstraints(minHeight: height) : null,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        crossAxisAlignment:
            autoGrow ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            Padding(
              padding: EdgeInsets.only(bottom: autoGrow ? 14 : 0),
              child: IconTheme(
                data:
                    const IconThemeData(size: 14, color: SpaceNotesTheme.muted),
                child: leading!,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              maxLines: maxLines,
              minLines: minLines,
              expands: expands,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 14,
                color: SpaceNotesTheme.fg,
                height: 1.4,
              ),
              textAlignVertical: TextAlignVertical.center,
              cursorColor: SpaceNotesTheme.accent,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 12,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 0.3,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(bottom: autoGrow ? 14 : 0),
              child: IconTheme(
                data: const IconThemeData(
                    size: 14, color: SpaceNotesTheme.accent),
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
