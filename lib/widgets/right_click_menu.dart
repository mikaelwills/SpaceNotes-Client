import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class RightClickMenu extends StatelessWidget {
  final List<PopupMenuEntry<String>>? items;
  final void Function(String value)? onSelected;
  final Widget child;

  const RightClickMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton && items != null) {
          _show(context, event.position);
        }
      },
      child: child,
    );
  }

  void _show(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items!,
      color: SpaceNotesTheme.card,
      elevation: 0,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(SpaceNotesTheme.radiusXs)),
        side: BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
      ),
    ).then((value) {
      if (value != null && onSelected != null) {
        onSelected!(value);
      }
    });
  }
}
