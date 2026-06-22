import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import 'sn_button.dart';

class SnDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final SnButtonVariant variant;
  final Color? accent;

  const SnDialogAction({
    required this.label,
    this.onPressed,
    this.variant = SnButtonVariant.outline,
    this.accent,
  });
}

class SnDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<SnDialogAction> actions;
  final Color? edge;

  const SnDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.edge,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SpaceNotesTheme.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: edge ?? SpaceNotesTheme.hairlineStrong,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(SpaceNotesTheme.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: SpaceNotesTheme.muted,
                ),
              ),
              const SizedBox(height: SpaceNotesTheme.space4),
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: SpaceNotesTheme.space6),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: SpaceNotesTheme.space6),
                      Expanded(
                        child: SnButton(
                          label: actions[i].label,
                          onPressed: actions[i].onPressed,
                          variant: actions[i].variant,
                          accent: actions[i].accent,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SnDialogField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const SnDialogField({
    super.key,
    required this.controller,
    this.hint = '',
    this.onSubmitted,
    this.autofocus = true,
  });

  @override
  State<SnDialogField> createState() => _SnDialogFieldState();
}

class _SnDialogFieldState extends State<SnDialogField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bgAlt,
        border: Border(
          left: BorderSide(color: SpaceNotesTheme.accent, width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const Text(
            '❯',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SpaceNotesTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.done,
              cursorColor: SpaceNotesTheme.accent,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 14,
                color: SpaceNotesTheme.fg,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '',
                hintStyle: TextStyle(color: SpaceNotesTheme.dim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
