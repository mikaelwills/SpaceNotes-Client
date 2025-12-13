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
  final VoidCallback? onImagePickerTap;
  final bool showImagePicker;
  final bool hasImageAttached;
  final VoidCallback? onClearImage;

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
    this.onImagePickerTap,
    this.showImagePicker = false,
    this.hasImageAttached = false,
    this.onClearImage,
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
    final hasText = widget.controller.text.isNotEmpty;
    final showImage = widget.showImagePicker;
    final hasImage = widget.hasImageAttached;

    if (!hasText && !showImage && !hasImage) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasText)
          GestureDetector(
            onTap: _handleClear,
            child: const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(
                Icons.clear,
                color: SpaceNotesTheme.textSecondary,
                size: 25,
              ),
            ),
          ),
        if (hasImage)
          Transform.translate(
            offset: const Offset(6, 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onClearImage?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image,
                      color: SpaceNotesTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.close,
                      color: SpaceNotesTheme.primary.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (showImage && !hasImage)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onImagePickerTap?.call();
            },
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.image_outlined,
                color: SpaceNotesTheme.primary,
                size: 24,
              ),
            ),
          ),
      ],
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
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          suffixIcon: _buildSuffixIcon(),
          minHeight: widget.height ?? 48,
          showBorders: false,
          dynamicHeight: true,
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
