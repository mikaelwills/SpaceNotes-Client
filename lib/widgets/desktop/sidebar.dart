import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../generated/folder.dart';
import '../../generated/note.dart';
import '../../providers/notes_providers.dart';
import '../../theme/spacenotes_theme.dart';
import 'desktop_shell.dart';

final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return Container(
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(isCollapsed: isCollapsed),
          if (!isCollapsed) ...[
            Expanded(child: _FolderTree()),
            const _SidebarSearch(),
            const _SidebarFooter(),
          ] else
            Expanded(child: _CollapsedSidebar()),
        ],
      ),
    );
  }
}

class _SidebarHeader extends ConsumerWidget {
  final bool isCollapsed;

  const _SidebarHeader({required this.isCollapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 18,
            ),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () {
              ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
            },
            tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 8),
            Text(
              'Notes',
              style: SpaceNotesTextStyles.terminal.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarSearch extends ConsumerStatefulWidget {
  const _SidebarSearch();

  @override
  ConsumerState<_SidebarSearch> createState() => _SidebarSearchState();
}

class _SidebarSearchState extends ConsumerState<_SidebarSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(folderSearchQueryProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(folderSearchQueryProvider.notifier).state = value;
    if (value.isNotEmpty) {
      final location = GoRouterState.of(context).uri.toString();
      if (!location.startsWith('/notes') || location.contains('/note/') || location.contains('/folder/')) {
        context.go('/notes');
      }
    }
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    final hasQuery = searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: SpaceNotesTheme.inputSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              size: 16,
              color: hasQuery ? SpaceNotesTheme.primary : SpaceNotesTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 12),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: SpaceNotesTextStyles.terminal.copyWith(
                    fontSize: 12,
                    color: SpaceNotesTheme.textSecondary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (hasQuery)
              GestureDetector(
                onTap: _clearSearch,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: SpaceNotesTheme.textSecondary,
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _FolderTree extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersListProvider);
    final notesAsync = ref.watch(notesListProvider);

    return foldersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(SpaceNotesTheme.primary),
        ),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: SpaceNotesTextStyles.terminal.copyWith(
            color: SpaceNotesTheme.error,
            fontSize: 12,
          ),
        ),
      ),
      data: (folders) {
        final notes = notesAsync.valueOrNull ?? [];
        final rootFolders = folders.where((f) => f.depth == 0).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final rootNotes = notes.where((n) => n.depth == 0).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            ...rootFolders.map((folder) => _FolderTreeItem(
                  folder: folder,
                  allFolders: folders,
                  allNotes: notes,
                  indentLevel: 0,
                )),
            ...rootNotes.map((note) => _NoteTreeItem(
                  note: note,
                  indentLevel: 0,
                )),
          ],
        );
      },
    );
  }
}

class _FolderTreeItem extends ConsumerWidget {
  final Folder folder;
  final List<Folder> allFolders;
  final List<Note> allNotes;
  final int indentLevel;

  const _FolderTreeItem({
    required this.folder,
    required this.allFolders,
    required this.allNotes,
    required this.indentLevel,
  });

  void _handleFolderAction(BuildContext context, WidgetRef ref, Folder folder, String action) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (action) {
      case 'new_note':
        final now = DateTime.now();
        final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
        final notePath = '${folder.path}/Untitled-$timestamp.md';
        final noteId = await repo.createNote(notePath, '# \n');
        if (noteId != null && context.mounted) {
          final encodedPath = notePath.split('/').map(Uri.encodeComponent).join('/');
          context.go('/notes/note/$encodedPath');
        }
        break;
      case 'new_folder':
        // TODO: Show dialog to create subfolder
        break;
      case 'rename':
        // TODO: Show rename dialog
        break;
      case 'delete':
        repo.deleteFolder(folder.path);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedFolders = ref.watch(expandedFoldersProvider);
    final isExpanded = expandedFolders.contains(folder.path);

    final normalizedPath = folder.path.endsWith('/')
        ? folder.path.substring(0, folder.path.length - 1)
        : folder.path;

    final childFolders = allFolders.where((f) {
      if (!f.path.startsWith('$normalizedPath/')) return false;
      final remainder = f.path.substring(normalizedPath.length + 1);
      return !remainder.contains('/');
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final folderPathWithSlash = '$normalizedPath/';
    final childNotes = allNotes
        .where((n) => n.folderPath == folderPathWithSlash)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final hasChildren = childFolders.isNotEmpty || childNotes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeItemRow(
          label: folder.name,
          indentLevel: indentLevel,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          isFolder: true,
          onTap: () {
            final current = ref.read(expandedFoldersProvider);
            if (current.contains(folder.path)) {
              ref.read(expandedFoldersProvider.notifier).state = {
                ...current
              }..remove(folder.path);
            } else {
              ref.read(expandedFoldersProvider.notifier).state = {
                ...current,
                folder.path
              };
            }
          },
          onAddNote: () => _handleFolderAction(context, ref, folder, 'new_note'),
          contextMenuItems: [
            PopupMenuItem(
              value: 'new_note',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('New Note', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
            ),
            PopupMenuItem(
              value: 'new_folder',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('New Folder', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'rename',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Rename', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
            ),
            PopupMenuItem(
              value: 'delete',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Delete', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13, color: SpaceNotesTheme.error)),
            ),
          ],
          onContextMenuSelected: (action) {
            _handleFolderAction(context, ref, folder, action);
          },
        ),
        if (isExpanded) ...[
          ...childFolders.map((f) => _FolderTreeItem(
                folder: f,
                allFolders: allFolders,
                allNotes: allNotes,
                indentLevel: indentLevel + 1,
              )),
          ...childNotes.map((n) => _NoteTreeItem(
                note: n,
                indentLevel: indentLevel + 1,
              )),
        ],
      ],
    );
  }
}

class _NoteTreeItem extends ConsumerWidget {
  final Note note;
  final int indentLevel;

  const _NoteTreeItem({
    required this.note,
    required this.indentLevel,
  });

  void _handleNoteAction(BuildContext context, WidgetRef ref, Note note, String action) {
    final repo = ref.read(notesRepositoryProvider);
    switch (action) {
      case 'rename':
        // TODO: Show rename dialog
        break;
      case 'delete':
        repo.deleteNote(note.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = note.name.endsWith('.md')
        ? note.name.substring(0, note.name.length - 3)
        : note.name;

    return _TreeItemRow(
      label: displayName,
      indentLevel: indentLevel,
      hasChildren: false,
      isExpanded: false,
      isFolder: false,
      onTap: () {
        final encodedPath =
            note.path.split('/').map(Uri.encodeComponent).join('/');
        final route = '/notes/note/$encodedPath';
        context.go(route);
      },
      contextMenuItems: [
        PopupMenuItem(
          value: 'rename',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Rename', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Delete', style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13, color: SpaceNotesTheme.error)),
        ),
      ],
      onContextMenuSelected: (action) {
        _handleNoteAction(context, ref, note, action);
      },
    );
  }
}

class _TreeItemRow extends StatefulWidget {
  final String label;
  final int indentLevel;
  final bool hasChildren;
  final bool isExpanded;
  final bool isFolder;
  final VoidCallback onTap;
  final VoidCallback? onAddNote;
  final List<PopupMenuEntry<String>>? contextMenuItems;
  final void Function(String)? onContextMenuSelected;

  const _TreeItemRow({
    required this.label,
    required this.indentLevel,
    required this.hasChildren,
    required this.isExpanded,
    required this.isFolder,
    required this.onTap,
    this.onAddNote,
    this.contextMenuItems,
    this.onContextMenuSelected,
  });

  @override
  State<_TreeItemRow> createState() => _TreeItemRowState();
}

class _TreeItemRowState extends State<_TreeItemRow> {
  bool _isHovered = false;

  void _showContextMenu(BuildContext context, Offset position) {
    if (widget.contextMenuItems == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: widget.contextMenuItems!,
      color: SpaceNotesTheme.inputSurface,
      elevation: 8,
      menuPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    ).then((value) {
      if (value != null && widget.onContextMenuSelected != null) {
        widget.onContextMenuSelected!(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final indent = 8.0 + (widget.indentLevel * 16.0);

    return Listener(
      onPointerDown: (event) {
        if (event.buttons == 2) {
          _showContextMenu(context, event.position);
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered
                ? SpaceNotesTheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          padding: EdgeInsets.only(left: indent, right: 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: Row(
                    children: [
                      if (widget.hasChildren)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 16,
                            color: SpaceNotesTheme.primary,
                          ),
                        )
                      else
                        const SizedBox(width: 20),
                      Icon(
                        widget.isFolder
                            ? Icons.folder_outlined
                            : Icons.description_outlined,
                        size: 16,
                        color: SpaceNotesTheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: SpaceNotesTextStyles.terminal.copyWith(
                            fontSize: 14,
                            color: _isHovered
                                ? SpaceNotesTheme.primary
                                : SpaceNotesTheme.text.withValues(alpha: 0.75),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isFolder && widget.isExpanded && _isHovered && widget.onAddNote != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onAddNote,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: const BoxDecoration(
                        color: SpaceNotesTheme.inputSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: SpaceNotesTheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedSidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _CollapsedIconButton(
          icon: Icons.folder,
          tooltip: 'Notes',
          onTap: () => context.go('/notes'),
        ),
        _CollapsedIconButton(
          icon: Icons.chat_bubble_outline,
          tooltip: 'Chat',
          onTap: () => context.go('/notes/chat'),
        ),
        _CollapsedIconButton(
          icon: Icons.search,
          tooltip: 'Search',
          onTap: () {},
        ),
      ],
    );
  }
}

class _CollapsedIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_CollapsedIconButton> createState() => _CollapsedIconButtonState();
}

class _CollapsedIconButtonState extends State<_CollapsedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: _isHovered
                  ? SpaceNotesTheme.inputSurface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () {},
            tooltip: 'New note',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () {},
            tooltip: 'New folder',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
