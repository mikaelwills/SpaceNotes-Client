import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/folder.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'right_click_menu.dart';

class FolderGridCard extends ConsumerStatefulWidget {
  const FolderGridCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.contextMenuItems,
    this.onContextMenuSelected,
  });

  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final List<PopupMenuEntry<String>>? contextMenuItems;
  final void Function(String value)? onContextMenuSelected;

  @override
  ConsumerState<FolderGridCard> createState() => _FolderGridCardState();
}

class _FolderGridCardState extends ConsumerState<FolderGridCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final noteCount = ref.watch(folderNoteCountProvider(widget.folder.path));

    return RightClickMenu(
      items: widget.contextMenuItems,
      onSelected: widget.onContextMenuSelected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: _isHovered ? SpaceNotesTheme.bgAlt : SpaceNotesTheme.card,
              border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: SpaceNotesTheme.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 13,
                      color: SpaceNotesTheme.fg,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (noteCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    noteCount.toString(),
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 11,
                      color: SpaceNotesTheme.dim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FolderCardGrid extends StatelessWidget {
  final List<Folder> folders;
  final void Function(Folder folder) onTap;
  final void Function(Folder folder)? onLongPress;
  final List<PopupMenuEntry<String>>? Function(Folder folder)? contextMenuItems;
  final void Function(Folder folder, String value)? onContextMenuSelected;

  const FolderCardGrid({
    super.key,
    required this.folders,
    required this.onTap,
    this.onLongPress,
    this.contextMenuItems,
    this.onContextMenuSelected,
  });

  static const _targetCardWidth = 180.0;
  static const _columnGap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = ((constraints.maxWidth + _columnGap) /
                (_targetCardWidth + _columnGap))
            .floor()
            .clamp(2, 6);
        final columnWidth =
            (constraints.maxWidth - _columnGap * (columnCount - 1)) /
                columnCount;

        final columns = List.generate(columnCount, (_) => <Folder>[]);
        for (var i = 0; i < folders.length; i++) {
          columns[i % columnCount].add(folders[i]);
        }

        Widget buildCard(Folder folder) => FolderGridCard(
              key: ValueKey(folder.path),
              folder: folder,
              onTap: () => onTap(folder),
              onLongPress:
                  onLongPress == null ? null : () => onLongPress!(folder),
              contextMenuItems: contextMenuItems?.call(folder),
              onContextMenuSelected: onContextMenuSelected == null
                  ? null
                  : (value) => onContextMenuSelected!(folder, value),
            );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int c = 0; c < columnCount; c++) ...[
              if (c > 0) const SizedBox(width: _columnGap),
              SizedBox(
                width: columnWidth,
                child: Column(children: columns[c].map(buildCard).toList()),
              ),
            ],
          ],
        );
      },
    );
  }
}
