import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/space_file.dart';
import '../providers/file_selection_provider.dart';
import '../theme/spacenotes_theme.dart';

/// Enters select mode. Sits where the sort toggle normally does.
class FileSelectToggle extends ConsumerWidget {
  const FileSelectToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(fileSelectionProvider);

    return GestureDetector(
      key: const ValueKey('file-select-toggle'),
      onTap: () => ref.read(fileSelectionProvider.notifier).toggleMode(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Icon(
          selection.active
              ? Icons.check_circle_outline
              : Icons.checklist_rtl_outlined,
          size: 14,
          color:
              selection.active ? SpaceNotesTheme.primary : SpaceNotesTheme.dim,
        ),
      ),
    );
  }
}

/// The select-mode controls: how many are ticked, select-all, the actions
/// menu, and a way out.
///
/// Destructive actions stay behind the menu rather than sitting exposed next
/// to the count, so a mis-tap cannot delete a batch.
class FileSelectionControls extends ConsumerWidget {
  const FileSelectionControls({
    super.key,
    required this.files,
    required this.onDelete,
    required this.onMove,
  });

  final List<SpaceFile> files;
  final VoidCallback onDelete;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(fileSelectionProvider);
    final notifier = ref.read(fileSelectionProvider.notifier);
    final allSelected =
        files.isNotEmpty && selection.count == files.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${selection.count} selected',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          key: const ValueKey('file-select-all'),
          onTap: () => allSelected
              ? notifier.clearSelection()
              : notifier.selectAll(files.map((f) => f.id)),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              allSelected ? 'none' : 'all',
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 10,
                color: SpaceNotesTheme.dim,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        _SelectionMenu(
          enabled: selection.hasSelection,
          onDelete: onDelete,
          onMove: onMove,
        ),
        GestureDetector(
          key: const ValueKey('file-select-exit'),
          onTap: notifier.exit,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(Icons.close, size: 14, color: SpaceNotesTheme.dim),
          ),
        ),
      ],
    );
  }
}

class _SelectionMenu extends StatelessWidget {
  const _SelectionMenu({
    required this.enabled,
    required this.onDelete,
    required this.onMove,
  });

  final bool enabled;
  final VoidCallback onDelete;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('file-selection-menu'),
      enabled: enabled,
      tooltip: '',
      padding: EdgeInsets.zero,
      color: SpaceNotesTheme.background,
      icon: Icon(
        Icons.more_horiz,
        size: 16,
        color: enabled ? SpaceNotesTheme.text : SpaceNotesTheme.dim,
      ),
      onSelected: (value) {
        if (value == 'delete') onDelete();
        if (value == 'move') onMove();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          key: ValueKey('bulk-move'),
          value: 'move',
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(
            'Move to folder',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.text,
            ),
          ),
        ),
        PopupMenuItem(
          key: ValueKey('bulk-delete'),
          value: 'delete',
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(
            'Delete',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
