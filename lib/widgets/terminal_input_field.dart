import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class TerminalInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final double? height;
  final double? minHeight;
  final bool showBorders;
  final bool dynamicHeight;

  const TerminalInputField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.height,
    this.minHeight,
    this.showBorders = true,
    this.dynamicHeight = false,
  });

  @override
  State<TerminalInputField> createState() => _TerminalInputFieldState();
}

class _TerminalInputFieldState extends State<TerminalInputField> {
  @override
  Widget build(BuildContext context) {
    if (widget.dynamicHeight) {
      return _buildDynamicHeight();
    }
    return _buildFixedHeight();
  }

  Widget _buildFixedHeight() {
    return GestureDetector(
      onTap: () => widget.focusNode?.requestFocus(),
      child: Container(
        height: widget.height ?? 52,
        decoration: BoxDecoration(
          border: widget.showBorders
              ? const Border(
                  left: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                  right: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _buildTextField(expands: true, maxLines: null),
            ),
            if (widget.suffixIcon != null) widget.suffixIcon!,
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicHeight() {
    return GestureDetector(
      onTap: () => widget.focusNode?.requestFocus(),
      child: Container(
        constraints: BoxConstraints(minHeight: widget.minHeight ?? 48),
        decoration: BoxDecoration(
          border: widget.showBorders
              ? const Border(
                  left: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                  right: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                )
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(right: widget.suffixIcon != null ? 80 : 0),
              child: _buildTextField(expands: false, maxLines: 8, minLines: 1),
            ),
            if (widget.suffixIcon != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: widget.suffixIcon!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required bool expands, int? maxLines, int? minLines, bool centerVertically = false}) {
    const textStyle = TextStyle(
      fontFamily: 'FiraCode',
      fontSize: 14,
      color: SpaceNotesTheme.text,
    );
    const hintStyle = TextStyle(
      fontFamily: 'FiraCode',
      fontSize: 14,
      color: SpaceNotesTheme.textSecondary,
      overflow: TextOverflow.ellipsis,
    );
    final decoration = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      hintText: widget.hintText,
      hintStyle: hintStyle,
      hintMaxLines: 1,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );

    final verticalAlign = expands || centerVertically
        ? TextAlignVertical.center
        : TextAlignVertical.top;

    if (widget.validator != null) {
      return TextFormField(
        controller: widget.controller,
        textAlignVertical: verticalAlign,
        expands: expands,
        maxLines: maxLines,
        minLines: minLines,
        style: textStyle,
        decoration: decoration,
        keyboardType: widget.keyboardType,
        enabled: widget.enabled,
        focusNode: widget.focusNode,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
      );
    }

    return TextField(
      controller: widget.controller,
      textAlignVertical: verticalAlign,
      expands: expands,
      maxLines: maxLines,
      minLines: minLines,
      style: textStyle,
      decoration: decoration,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

