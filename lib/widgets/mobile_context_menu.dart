import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../theme/spacenotes_theme.dart';
import 'adaptive/platform_utils.dart';

class SpaceNotesContextMenu extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;

  const SpaceNotesContextMenu({
    super.key,
    required this.anchors,
    required this.buttonItems,
  });

  static const _kHandleHeight = 24.0;

  static Widget buildForQuill(
      BuildContext context, QuillRawEditorState rawEditorState) {
    if (!PlatformUtils.isMobilePlatform) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: rawEditorState.contextMenuAnchors,
        buttonItems: rawEditorState.contextMenuButtonItems,
      );
    }
    return SpaceNotesContextMenu(
      anchors: rawEditorState.contextMenuAnchors,
      buttonItems: rawEditorState.contextMenuButtonItems,
    );
  }

  static Widget buildForTextField(
      BuildContext context, EditableTextState editableTextState) {
    if (!PlatformUtils.isMobilePlatform) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: editableTextState,
      );
    }
    return SpaceNotesContextMenu(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: editableTextState.contextMenuButtonItems,
    );
  }

  static String _labelFor(ContextMenuButtonType type) {
    switch (type) {
      case ContextMenuButtonType.cut:
        return 'Cut';
      case ContextMenuButtonType.copy:
        return 'Copy';
      case ContextMenuButtonType.paste:
        return 'Paste';
      case ContextMenuButtonType.selectAll:
        return 'Select All';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = buttonItems
        .where((item) =>
            item.type == ContextMenuButtonType.cut ||
            item.type == ContextMenuButtonType.copy ||
            item.type == ContextMenuButtonType.paste ||
            item.type == ContextMenuButtonType.selectAll)
        .toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    final secondary = anchors.secondaryAnchor ?? anchors.primaryAnchor;
    final selectionHeight = (secondary.dy - anchors.primaryAnchor.dy).abs();
    final lineHeight = selectionHeight > 0 ? selectionHeight : 24.0;

    return TextSelectionToolbar(
      anchorAbove: Offset(
        anchors.primaryAnchor.dx,
        anchors.primaryAnchor.dy - (lineHeight + _kHandleHeight) * 1.5,
      ),
      anchorBelow: Offset(
        secondary.dx,
        secondary.dy + (lineHeight + _kHandleHeight) * 1.5,
      ),
      toolbarBuilder: (context, child) => Container(
        decoration: BoxDecoration(
          color: SpaceNotesTheme.inputSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: SpaceNotesTheme.primaryMuted.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
      children: filtered
          .map((item) => TextSelectionToolbarTextButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onPressed: item.onPressed,
                child: Text(
                  _labelFor(item.type),
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 13,
                    color: SpaceNotesTheme.primary,
                  ),
                ),
              ))
          .toList(),
    );
  }
}
