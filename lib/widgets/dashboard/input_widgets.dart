import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';

/// Themed multiline text input for generative-UI dashboards.
///
/// The widget is "dumb" by design: it knows its current value and fires
/// onChanged when the user types. It does NOT know which note it lives in,
/// which binding key it represents, or how the value is persisted. The
/// Surface (or the gallery demo) owns those concerns.
class DashTextField extends StatefulWidget {
  final String label;
  final String value;
  final String? hint;
  final bool multiline;
  final ValueChanged<String>? onChanged;

  const DashTextField({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.multiline = true,
    this.onChanged,
  });

  @override
  State<DashTextField> createState() => _DashTextFieldState();
}

class _DashTextFieldState extends State<DashTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant DashTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: selection.baseOffset <= widget.value.length
            ? selection
            : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.muted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border.all(
              color: SpaceNotesTheme.hairlineStrong,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: widget.multiline ? null : 1,
            minLines: widget.multiline ? 3 : 1,
            cursorColor: SpaceNotesTheme.accent,
            cursorWidth: 1.5,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 13,
              color: SpaceNotesTheme.fg,
              height: 1.5,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.dim,
                height: 1.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }
}
