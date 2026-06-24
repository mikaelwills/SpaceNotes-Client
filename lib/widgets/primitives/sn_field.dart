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
    this.height = 52,
    this.radius = SpaceNotesTheme.radiusDock,
    this.background = SpaceNotesTheme.bgAlt,
    this.borderColor = SpaceNotesTheme.hairlineStrong,
  });

  @override
  Widget build(BuildContext context) {
    final autoGrow = expands || maxLines == null || (maxLines ?? 1) > 1;
    if (autoGrow) return _buildAutoGrow();
    return _buildFixedHeight();
  }

  Widget _buildFixedHeight() {
    return Container(
      height: height,
      decoration: _decoration(),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: const IconThemeData(size: 18, color: SpaceNotesTheme.muted),
              child: leading!,
            ),
            const SizedBox(width: 10),
          ],
          // expands:true fills the full row height → text centers via
          // textAlignVertical AND the whole box is the tap target.
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: SpaceNotesTheme.accent,
              cursorWidth: 1.5,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
                height: 1.0,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 13,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 0.3,
                  height: 1.0,
                  overflow: TextOverflow.ellipsis,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data:
                  const IconThemeData(size: 18, color: SpaceNotesTheme.accent),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoGrow() {
    final hasLeading = leading != null;
    final hasTrailing = trailing != null;
    return GestureDetector(
      onTap: () => focusNode?.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: _decoration(),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasLeading) ...[
              IconTheme(
                data:
                    const IconThemeData(size: 18, color: SpaceNotesTheme.muted),
                child: leading!,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: _buildTextField()),
            if (hasTrailing) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: const IconThemeData(
                    size: 18, color: SpaceNotesTheme.accent),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      style: const TextStyle(
        fontFamily: SpaceNotesTheme.fontSans,
        fontSize: 15,
        color: SpaceNotesTheme.fg,
        height: 1.0,
      ),
      textAlignVertical: TextAlignVertical.center,
      cursorColor: SpaceNotesTheme.accent,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintMaxLines: 1,
        hintStyle: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 13,
          color: SpaceNotesTheme.dim,
          letterSpacing: 0.3,
          height: 1.0,
          overflow: TextOverflow.ellipsis,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
      ),
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(radius),
      );
}
