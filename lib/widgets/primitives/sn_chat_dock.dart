import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/spacenotes_theme.dart';
import 'sn_field.dart';

/// Shared chat-input dock: a transparent gradient overlay + a single
/// borderless surface holding the field and flush, hairline-separated tiles.
/// Used by the mobile global bar, the desktop chat rail, and the note-chat
/// panel. Caller owns the controller/focus and passes callbacks + optional
/// leading/trailing tiles.
class SnChatDock extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback onSend;
  final bool showSend;
  final Widget? fieldTrailing;
  final List<Widget> leading;
  final List<Widget> trailing;
  final EdgeInsets padding;
  final int maxLines;
  final int minLines;
  final bool showFade;
  final double fieldMinHeight;
  final double? fieldPadV;
  final double sendTileSize;

  const SnChatDock({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.focusNode,
    this.onChanged,
    this.showSend = true,
    this.fieldTrailing,
    this.leading = const [],
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 12),
    this.maxLines = 6,
    this.minLines = 1,
    this.showFade = true,
    this.fieldMinHeight = 52,
    this.fieldPadV,
    this.sendTileSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showFade)
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SpaceNotesTheme.bgAlt,
              border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
              borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _tiles(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _tiles() {
    return <Widget>[
      ...leading,
      Expanded(
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey != LogicalKeyboardKey.enter) {
              return KeyEventResult.ignored;
            }
            if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            }
            onSend();
            return KeyEventResult.handled;
          },
          child: SnField(
            controller: controller,
            focusNode: focusNode,
            hint: hint,
            onChanged: onChanged,
            onSubmitted: (_) => onSend(),
            maxLines: maxLines,
            minLines: minLines,
            height: fieldMinHeight,
            autoGrowPadV: fieldPadV,
            trailing: fieldTrailing,
            background: Colors.transparent,
            borderColor: Colors.transparent,
          ),
        ),
      ),
      ...trailing,
      if (showSend)
        SnDockTile(
          icon: Icons.arrow_upward,
          onTap: onSend,
          semanticLabel: 'send',
          size: sendTileSize,
        ),
    ];
  }
}

class SnDockTile extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color color;
  final double size;

  const SnDockTile({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.color = SpaceNotesTheme.accent,
    this.size = 52,
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
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
