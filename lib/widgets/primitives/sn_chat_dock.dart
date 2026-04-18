import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/spacenotes_theme.dart';
import 'sn_field.dart';

/// Shared chat-input dock: a transparent gradient overlay + SnField + tiles.
/// Used by the mobile global bar, the desktop chat rail, and the note-chat
/// panel. Caller owns the controller/focus and passes callbacks + optional
/// leading/trailing tiles.
class SnChatDock extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback onSend;
  final Widget? fieldTrailing;
  final List<Widget> leading;
  final List<Widget> trailing;
  final EdgeInsets padding;
  final int maxLines;
  final int minLines;

  const SnChatDock({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.focusNode,
    this.onChanged,
    this.fieldTrailing,
    this.leading = const [],
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 12),
    this.maxLines = 6,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 1.0],
                  colors: [
                    Color(0x000D0D0F),
                    Color(0xCC0D0D0F),
                    Color(0xFF0D0D0F),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final w in leading) ...[w, const SizedBox(width: 8)],
              Expanded(
                child: SnField(
                  controller: controller,
                  focusNode: focusNode,
                  hint: hint,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSend(),
                  maxLines: maxLines,
                  minLines: minLines,
                  trailing: fieldTrailing,
                ),
              ),
              for (final w in trailing) ...[const SizedBox(width: 8), w],
              const SizedBox(width: 8),
              SnDockTile(
                icon: Icons.arrow_upward,
                onTap: onSend,
                semanticLabel: 'send',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SnDockTile extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const SnDockTile({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border.all(
              color: SpaceNotesTheme.hairlineStrong,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusDock),
          ),
          child: Icon(icon, size: 16, color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }
}
