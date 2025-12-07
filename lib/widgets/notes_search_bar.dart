import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import 'terminal_input_field.dart';

class NotesSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool isLoading;
  final String? errorText;
  final double? height;
  final String? hintText;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onSubmitted;

  const NotesSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.isLoading = false,
    this.errorText,
    this.height,
    this.hintText,
    this.onFocusChanged,
    this.onSubmitted,
  });

  @override
  State<NotesSearchBar> createState() => _NotesSearchBarState();
}

class _NotesSearchBarState extends State<NotesSearchBar> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  void _handleClear() {
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    HapticFeedback.lightImpact();
  }

  Widget? _buildSuffixIcon() {
    if (widget.controller.text.isEmpty) return null;

    return GestureDetector(
      onTap: _handleClear,
      child: const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(
          Icons.clear,
          color: SpaceNotesTheme.textSecondary,
          size: 25,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalInputField(
          controller: widget.controller,
          hintText: widget.hintText ?? 'Search notes...',
          onChanged: widget.onChanged,
          focusNode: _focusNode,
          textInputAction: TextInputAction.send,
          suffixIcon: _buildSuffixIcon(),
          height: widget.height,
          showBorders: false,
          onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 12,
                color: SpaceNotesTheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
