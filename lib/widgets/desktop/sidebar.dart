import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../generated/folder.dart';
import '../../generated/note.dart';
import '../../providers/notes_providers.dart';
import '../../theme/spacenotes_theme.dart';
import 'desktop_shell.dart';

final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});
final searchFocusRequestProvider = StateProvider<int>((ref) => 0);

void _openNoteInDesktop(BuildContext context, String notePath) {
  context.read<DesktopNotesBloc>().add(OpenNote(notePath));
  final location = GoRouterState.of(context).uri.toString();
  if (location == '/notes/chat' || location == '/settings') {
    context.go('/notes');
  }
}

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
    if (isCollapsed) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () {
              ref.read(sidebarCollapsedProvider.notifier).state = false;
            },
            tooltip: 'Expand sidebar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'SpaceNotes',
            style: SpaceNotesTextStyles.terminal.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: SpaceNotesTheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () {
              ref.read(sidebarCollapsedProvider.notifier).state = true;
            },
            tooltip: 'Collapse sidebar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
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

    ref.listen<int>(searchFocusRequestProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    });

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
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
              color: hasQuery
                  ? SpaceNotesTheme.primary
                  : SpaceNotesTheme.textSecondary,
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

class _FolderTree extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends ConsumerState<_FolderTree> {
  bool _isDragOverRoot = false;
  String _lastSearchQuery = '';
  Set<String> _expandedBeforeSearch = {};

  bool _canAcceptAtRoot(_DraggableData data) {
    if (!data.path.contains('/')) return false;
    return true;
  }

  void _handleDropAtRoot(_DraggableData data) async {
    final repo = ref.read(notesRepositoryProvider);
    final newPath = data.name;

    if (data.isFolder) {
      await repo.moveFolder(data.path, newPath);
    } else {
      await repo.moveNote(data.path, newPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersListProvider);
    final notesAsync = ref.watch(notesListProvider);
    final searchQuery = ref.watch(folderSearchQueryProvider).toLowerCase();
    final isSearching = searchQuery.isNotEmpty;

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

        Set<String> visibleFolderPaths = {};
        Set<String> foldersToExpand = {};
        Set<String> matchingNotePaths = {};
        Set<String> matchingFolderPaths = {};

        if (isSearching) {
          for (final note in notes) {
            if (note.name.toLowerCase().contains(searchQuery)) {
              matchingNotePaths.add(note.path);
              String parentPath = note.folderPath;
              while (parentPath.isNotEmpty) {
                if (parentPath.endsWith('/')) {
                  parentPath = parentPath.substring(0, parentPath.length - 1);
                }
                if (parentPath.isNotEmpty) {
                  visibleFolderPaths.add(parentPath);
                  foldersToExpand.add(parentPath);
                }
                final lastSlash = parentPath.lastIndexOf('/');
                parentPath = lastSlash > 0 ? parentPath.substring(0, lastSlash) : '';
              }
            }
          }

          for (final folder in folders) {
            if (folder.name.toLowerCase().contains(searchQuery)) {
              matchingFolderPaths.add(folder.path);
              visibleFolderPaths.add(folder.path);
              String parentPath = folder.path;
              while (parentPath.contains('/')) {
                final lastSlash = parentPath.lastIndexOf('/');
                parentPath = parentPath.substring(0, lastSlash);
                if (parentPath.isNotEmpty) {
                  visibleFolderPaths.add(parentPath);
                  foldersToExpand.add(parentPath);
                }
              }
            }
          }

          if (matchingNotePaths.isEmpty && matchingFolderPaths.isEmpty) {
            _lastSearchQuery = searchQuery;
            return Center(
              child: Text(
                'No results',
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            );
          }

          if (_lastSearchQuery.isEmpty && searchQuery.isNotEmpty) {
            _expandedBeforeSearch = Set.from(ref.read(expandedFoldersProvider));
          }
          if (searchQuery != _lastSearchQuery) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(expandedFoldersProvider.notifier).state =
                  Set.from(foldersToExpand);
            });
          }
          _lastSearchQuery = searchQuery;
        } else if (_lastSearchQuery.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(expandedFoldersProvider.notifier).state = _expandedBeforeSearch;
          });
          _lastSearchQuery = '';
        }

        final rootFolders = folders.where((f) {
          if (f.depth != 0) return false;
          if (!isSearching) return true;
          return visibleFolderPaths.contains(f.path) || matchingFolderPaths.contains(f.path);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final rootNotes = notes.where((n) {
          if (n.depth != 0) return false;
          if (!isSearching) return true;
          return matchingNotePaths.contains(n.path);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  ...rootFolders.map((folder) => _FolderTreeItem(
                        folder: folder,
                        allFolders: folders,
                        allNotes: notes,
                        indentLevel: 0,
                        searchQuery: searchQuery,
                        visibleFolderPaths: visibleFolderPaths,
                        matchingNotePaths: matchingNotePaths,
                        matchingFolderPaths: matchingFolderPaths,
                      )),
                  ...rootNotes.map((note) => _NoteTreeItem(
                        note: note,
                        allFolders: folders,
                        indentLevel: 0,
                        isMatch: matchingNotePaths.contains(note.path),
                      )),
                ],
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: DragTarget<_DraggableData>(
                  onWillAcceptWithDetails: (details) {
                    final canAccept = _canAcceptAtRoot(details.data);
                    if (canAccept && !_isDragOverRoot) {
                      setState(() => _isDragOverRoot = true);
                    }
                    return canAccept;
                  },
                  onLeave: (_) => setState(() => _isDragOverRoot = false),
                  onAcceptWithDetails: (details) {
                    setState(() => _isDragOverRoot = false);
                    _handleDropAtRoot(details.data);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return const SizedBox.expand();
                  },
                ),
              ),
              if (_isDragOverRoot)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: SpaceNotesTheme.primary.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableData {
  final bool isFolder;
  final String path;
  final String name;

  const _DraggableData(
      {required this.isFolder, required this.path, required this.name});
}

class _FolderTreeItem extends ConsumerStatefulWidget {
  final Folder folder;
  final List<Folder> allFolders;
  final List<Note> allNotes;
  final int indentLevel;
  final String searchQuery;
  final Set<String> visibleFolderPaths;
  final Set<String> matchingNotePaths;
  final Set<String> matchingFolderPaths;
  final bool showAllChildren;

  const _FolderTreeItem({
    required this.folder,
    required this.allFolders,
    required this.allNotes,
    required this.indentLevel,
    this.searchQuery = '',
    this.visibleFolderPaths = const {},
    this.matchingNotePaths = const {},
    this.matchingFolderPaths = const {},
    this.showAllChildren = false,
  });

  @override
  ConsumerState<_FolderTreeItem> createState() => _FolderTreeItemState();
}

class _FolderTreeItemState extends ConsumerState<_FolderTreeItem> {
  bool _isDragOver = false;

  void _handleFolderAction(
      BuildContext context, WidgetRef ref, Folder folder, String action) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (action) {
      case 'new_note':
        final now = DateTime.now();
        final timestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
        final notePath = '${folder.path}/Untitled-$timestamp.md';
        final noteId = await repo.createNote(notePath, '');
        if (noteId != null && context.mounted) {
          _openNoteInDesktop(context, notePath);
        }
        break;
      case 'new_folder':
        final controller = TextEditingController();
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SpaceNotesTheme.inputSurface,
            title: Text('New Folder',
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: SpaceNotesTextStyles.terminal,
              decoration: InputDecoration(
                hintText: 'Folder name',
                hintStyle: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.textSecondary),
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text('Create',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.primary)),
              ),
            ],
          ),
        );
        if (result != null && result.isNotEmpty && context.mounted) {
          final newFolderPath = '${folder.path}/$result';
          final existingFolder = widget.allFolders.any((f) => f.path == newFolderPath);
          if (existingFolder) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: SpaceNotesTheme.inputSurface,
                  title: Text('Folder Exists',
                      style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
                  content: Text(
                    'A folder named "$result" already exists here.',
                    style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('OK',
                          style: SpaceNotesTextStyles.terminal
                              .copyWith(color: SpaceNotesTheme.primary)),
                    ),
                  ],
                ),
              );
            }
          } else {
            await repo.createFolder(newFolderPath);
          }
        }
        break;
      case 'rename':
        final controller = TextEditingController(text: folder.name);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SpaceNotesTheme.inputSurface,
            title: Text('Rename Folder',
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: SpaceNotesTextStyles.terminal,
              decoration: InputDecoration(
                hintText: 'Folder name',
                hintStyle: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.textSecondary),
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text('Rename',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.primary)),
              ),
            ],
          ),
        );
        if (result != null && result.isNotEmpty && result != folder.name && context.mounted) {
          final parentPath = folder.path.contains('/')
              ? folder.path.substring(0, folder.path.lastIndexOf('/'))
              : '';
          final newPath = parentPath.isEmpty ? result : '$parentPath/$result';
          await repo.moveFolder(folder.path, newPath);
        }
        break;
      case 'delete':
        final childFolders = widget.allFolders.where((f) =>
            f.path.startsWith('${folder.path}/'));
        final childNotes = widget.allNotes.where((n) =>
            n.path.startsWith('${folder.path}/'));
        final hasChildren = childFolders.isNotEmpty || childNotes.isNotEmpty;

        if (hasChildren) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: SpaceNotesTheme.inputSurface,
              title: Text('Delete Folder?',
                  style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
              content: Text(
                'This folder contains items. Are you sure you want to delete "${folder.name}" and all its contents?',
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancel',
                      style: SpaceNotesTextStyles.terminal
                          .copyWith(color: SpaceNotesTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('Delete',
                      style: SpaceNotesTextStyles.terminal
                          .copyWith(color: SpaceNotesTheme.error)),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
        }
        repo.deleteFolder(folder.path);
        break;
    }
  }

  bool _canAcceptDrop(_DraggableData data) {
    final targetPath = widget.folder.path;
    if (data.isFolder) {
      if (data.path == targetPath) return false;
      if (targetPath.startsWith('${data.path}/')) return false;
    }
    return true;
  }

  void _handleDrop(_DraggableData data) async {
    final repo = ref.read(notesRepositoryProvider);
    final newPath = '${widget.folder.path}/${data.name}';

    if (data.isFolder) {
      await repo.moveFolder(data.path, newPath);
    } else {
      await repo.moveNote(data.path, newPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expandedFolders = ref.watch(expandedFoldersProvider);
    final isSearching = widget.searchQuery.isNotEmpty;
    final isExpanded = expandedFolders.contains(widget.folder.path);

    final thisFolderMatches = widget.matchingFolderPaths.contains(widget.folder.path);
    final normalizedPath = widget.folder.path.endsWith('/')
        ? widget.folder.path.substring(0, widget.folder.path.length - 1)
        : widget.folder.path;
    final folderPathWithSlash = '$normalizedPath/';
    final hasMatchingNotesInside = widget.matchingNotePaths.any((p) => p.startsWith(folderPathWithSlash));
    final hasMatchingFoldersInside = widget.matchingFolderPaths.any((p) => p != widget.folder.path && p.startsWith(folderPathWithSlash));
    final hasMatchingChildrenInside = hasMatchingNotesInside || hasMatchingFoldersInside;
    final shouldShowAllChildren = widget.showAllChildren || (thisFolderMatches && !hasMatchingChildrenInside);

    final childFolders = widget.allFolders.where((f) {
      if (!f.path.startsWith(folderPathWithSlash)) return false;
      final remainder = f.path.substring(folderPathWithSlash.length);
      if (remainder.contains('/')) return false;
      if (!isSearching || shouldShowAllChildren) return true;
      return widget.visibleFolderPaths.contains(f.path) ||
             widget.matchingFolderPaths.contains(f.path);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final childNotes = widget.allNotes.where((n) {
      if (n.folderPath != folderPathWithSlash) return false;
      if (!isSearching || shouldShowAllChildren) return true;
      return widget.matchingNotePaths.contains(n.path);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final hasChildren = childFolders.isNotEmpty || childNotes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<_DraggableData>(
          onWillAcceptWithDetails: (details) {
            final canAccept = _canAcceptDrop(details.data);
            if (canAccept && !_isDragOver) {
              setState(() => _isDragOver = true);
            }
            return canAccept;
          },
          onLeave: (_) => setState(() => _isDragOver = false),
          onAcceptWithDetails: (details) {
            setState(() => _isDragOver = false);
            _handleDrop(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            return Draggable<_DraggableData>(
              data: _DraggableData(
                isFolder: true,
                path: widget.folder.path,
                name: widget.folder.name,
              ),
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SpaceNotesTheme.inputSurface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: SpaceNotesTheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 14, color: SpaceNotesTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        widget.folder.name,
                        style: SpaceNotesTextStyles.terminal.copyWith(
                            fontSize: 12, color: SpaceNotesTheme.text),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child:
                    _buildTreeRow(hasChildren, isExpanded, isDragOver: false),
              ),
              child: _buildTreeRow(hasChildren, isExpanded,
                  isDragOver: _isDragOver),
            );
          },
        ),
        if (isExpanded) ...[
          ...childFolders.map((f) => _FolderTreeItem(
                folder: f,
                allFolders: widget.allFolders,
                allNotes: widget.allNotes,
                indentLevel: widget.indentLevel + 1,
                searchQuery: widget.searchQuery,
                visibleFolderPaths: widget.visibleFolderPaths,
                matchingNotePaths: widget.matchingNotePaths,
                matchingFolderPaths: widget.matchingFolderPaths,
                showAllChildren: shouldShowAllChildren,
              )),
          ...childNotes.map((n) => _NoteTreeItem(
                note: n,
                allFolders: widget.allFolders,
                indentLevel: widget.indentLevel + 1,
                isMatch: widget.matchingNotePaths.contains(n.path),
              )),
        ],
      ],
    );
  }

  Widget _buildTreeRow(bool hasChildren, bool isExpanded,
      {required bool isDragOver}) {
    return _TreeItemRow(
      label: widget.folder.name,
      indentLevel: widget.indentLevel,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      isFolder: true,
      isDragOver: isDragOver,
      onTap: () {
        final current = ref.read(expandedFoldersProvider);
        if (current.contains(widget.folder.path)) {
          ref.read(expandedFoldersProvider.notifier).state = {...current}
            ..remove(widget.folder.path);
        } else {
          ref.read(expandedFoldersProvider.notifier).state = {
            ...current,
            widget.folder.path
          };
        }
      },
      onAddNote: () =>
          _handleFolderAction(context, ref, widget.folder, 'new_note'),
      contextMenuItems: [
        PopupMenuItem(
          value: 'new_note',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('New Note',
              style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'new_folder',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('New Folder',
              style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'rename',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Rename',
              style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Delete',
              style: SpaceNotesTextStyles.terminal
                  .copyWith(fontSize: 13, color: SpaceNotesTheme.error)),
        ),
      ],
      onContextMenuSelected: (action) {
        _handleFolderAction(context, ref, widget.folder, action);
      },
    );
  }
}

class _NoteTreeItem extends ConsumerWidget {
  final Note note;
  final List<Folder> allFolders;
  final int indentLevel;
  final bool isMatch;

  const _NoteTreeItem({
    required this.note,
    required this.allFolders,
    required this.indentLevel,
    this.isMatch = false,
  });

  void _handleNoteAction(
      BuildContext context, WidgetRef ref, Note note, String action) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (action) {
      case 'rename':
        final nameWithoutExt = note.name.endsWith('.md')
            ? note.name.substring(0, note.name.length - 3)
            : note.name;
        final controller = TextEditingController(text: nameWithoutExt);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SpaceNotesTheme.inputSurface,
            title: Text('Rename Note',
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: SpaceNotesTextStyles.terminal,
              decoration: InputDecoration(
                hintText: 'Note name',
                hintStyle: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.textSecondary),
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text('Rename',
                    style: SpaceNotesTextStyles.terminal
                        .copyWith(color: SpaceNotesTheme.primary)),
              ),
            ],
          ),
        );
        if (result != null && result.isNotEmpty && result != nameWithoutExt && context.mounted) {
          final newName = result.endsWith('.md') ? result : '$result.md';
          final folderPath = note.path.contains('/')
              ? note.path.substring(0, note.path.lastIndexOf('/'))
              : '';
          final newPath = folderPath.isEmpty ? newName : '$folderPath/$newName';
          await repo.moveNote(note.path, newPath);
        }
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

    return Draggable<_DraggableData>(
      data: _DraggableData(
        isFolder: false,
        path: note.path,
        name: note.name,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: SpaceNotesTheme.inputSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: SpaceNotesTheme.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined,
                  size: 14, color: SpaceNotesTheme.primary),
              const SizedBox(width: 6),
              Text(
                displayName,
                style: SpaceNotesTextStyles.terminal
                    .copyWith(fontSize: 12, color: SpaceNotesTheme.text),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildTreeRow(context, ref, displayName),
      ),
      child: _buildTreeRow(context, ref, displayName),
    );
  }

  Widget _buildTreeRow(
      BuildContext context, WidgetRef ref, String displayName) {
    return _TreeItemRow(
      label: displayName,
      indentLevel: indentLevel,
      hasChildren: false,
      isExpanded: false,
      isFolder: false,
      onTap: () {
        _openNoteInDesktop(context, note.path);
      },
      onDelete: () => _handleNoteAction(context, ref, note, 'delete'),
      contextMenuItems: [
        PopupMenuItem(
          value: 'rename',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Rename',
              style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Delete',
              style: SpaceNotesTextStyles.terminal
                  .copyWith(fontSize: 13, color: SpaceNotesTheme.error)),
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
  final bool isDragOver;
  final VoidCallback onTap;
  final VoidCallback? onAddNote;
  final VoidCallback? onDelete;
  final List<PopupMenuEntry<String>>? contextMenuItems;
  final void Function(String)? onContextMenuSelected;

  const _TreeItemRow({
    required this.label,
    required this.indentLevel,
    required this.hasChildren,
    required this.isExpanded,
    required this.isFolder,
    required this.onTap,
    this.isDragOver = false,
    this.onAddNote,
    this.onDelete,
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
            color: widget.isDragOver
                ? SpaceNotesTheme.primary.withValues(alpha: 0.2)
                : _isHovered
                    ? SpaceNotesTheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: widget.isDragOver
                ? Border.all(
                    color: SpaceNotesTheme.primary.withValues(alpha: 0.5),
                    width: 1)
                : null,
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
              if (widget.isFolder &&
                  widget.isExpanded &&
                  _isHovered &&
                  widget.onAddNote != null)
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
              if (!widget.isFolder && _isHovered && widget.onDelete != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: const BoxDecoration(
                        color: SpaceNotesTheme.inputSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: SpaceNotesTheme.error,
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
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            onTap: () {
              ref.read(sidebarCollapsedProvider.notifier).state = false;
              ref.read(searchFocusRequestProvider.notifier).state++;
            },
          ),
        ],
      ),
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

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter();

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notesRepositoryProvider);
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final notePath = 'All Notes/Untitled-$timestamp.md';
    final noteId = await repo.createNote(notePath, '');
    if (noteId != null && context.mounted) {
      _openNoteInDesktop(context, notePath);
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceNotesTheme.inputSurface,
        title: Text('New Folder',
            style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: SpaceNotesTextStyles.terminal,
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: SpaceNotesTextStyles.terminal
                .copyWith(color: SpaceNotesTheme.textSecondary),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Create',
                style: SpaceNotesTextStyles.terminal
                    .copyWith(color: SpaceNotesTheme.primary)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      final folders = ref.read(foldersListProvider).valueOrNull ?? [];
      final existingFolder = folders.any((f) => f.path == result);
      if (existingFolder) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: SpaceNotesTheme.inputSurface,
              title: Text('Folder Exists',
                  style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 16)),
              content: Text(
                'A folder named "$result" already exists.',
                style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('OK',
                      style: SpaceNotesTextStyles.terminal
                          .copyWith(color: SpaceNotesTheme.primary)),
                ),
              ],
            ),
          );
        }
      } else {
        final repo = ref.read(notesRepositoryProvider);
        await repo.createFolder(result);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () => _createNote(context, ref),
            tooltip: 'New note',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () => _createFolder(context, ref),
            tooltip: 'New folder',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            color: SpaceNotesTheme.textSecondary,
            onPressed: () => context.go('/notes/chat'),
            tooltip: 'AI Chat',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
