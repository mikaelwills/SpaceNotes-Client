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
  bool _isMultiline = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_checkMultiline);
    _checkMultiline();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_checkMultiline);
    super.dispose();
  }

  void _checkMultiline() {
    final text = widget.controller?.text ?? '';
    final hasNewline = text.contains('\n');
    if (hasNewline != _isMultiline) {
      setState(() => _isMultiline = hasNewline);
    }
  }

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
    if (_isMultiline) {
      return GestureDetector(
        onTap: () => widget.focusNode?.requestFocus(),
        child: Container(
          constraints: BoxConstraints(
            minHeight: widget.minHeight ?? 48,
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            border: widget.showBorders
                ? const Border(
                    left: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                    right: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                  )
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _buildTextField(expands: false, maxLines: null, minLines: 1),
              ),
              if (widget.suffixIcon != null) widget.suffixIcon!,
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => widget.focusNode?.requestFocus(),
      child: Container(
        height: widget.minHeight ?? 48,
        decoration: BoxDecoration(
          border: widget.showBorders
              ? const Border(
                  left: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                  right: BorderSide(color: SpaceNotesTheme.primary, width: 2),
                )
              : null,
        ),
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _buildTextField(expands: false, maxLines: 1),
            ),
            if (widget.suffixIcon != null) widget.suffixIcon!,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required bool expands, int? maxLines, int? minLines}) {
    const textStyle = TextStyle(
      fontFamily: 'FiraCode',
      fontSize: 14,
      color: SpaceNotesTheme.text,
    );
    const hintStyle = TextStyle(
      fontFamily: 'FiraCode',
      fontSize: 14,
      color: SpaceNotesTheme.textSecondary,
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
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );

    if (widget.validator != null) {
      return TextFormField(
        controller: widget.controller,
        textAlignVertical: expands ? TextAlignVertical.center : TextAlignVertical.top,
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
      textAlignVertical: expands ? TextAlignVertical.center : TextAlignVertical.top,
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

