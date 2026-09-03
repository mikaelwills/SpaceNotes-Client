import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/middle_pane_mode_provider.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/favourite_folder_menu.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/folder_grid_card.dart';
import '../providers/folder_browser_view_mode_provider.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';
import '../widgets/staggered_file_grid.dart';
import '../file_types/file_type_registry.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';

class FolderListView extends ConsumerStatefulWidget {
  final String folderPath;
  final bool tallFolderRows;

  const FolderListView({
    super.key,
    this.folderPath = '',
    this.tallFolderRows = false,
  });

  @override
  ConsumerState<FolderListView> createState() => _FolderListViewState();
}

class _FolderListViewState extends ConsumerState<FolderListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentFolderPathProvider.notifier).state = widget.folderPath;
      ref.read(currentNotePathProvider.notifier).state = null;
    });
  }

  @override
  void didUpdateWidget(FolderListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentFolderPathProvider.notifier).state = widget.folderPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dynamicFolderContentsProvider(widget.folderPath));
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    return Column(
      children: [
        if (!isDesktop)
          Container(
            height: 32,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
              ),
            ),
            child: const ViewModeToggle(),
          ),
        Expanded(child: _buildLoadedState(data.folders, data.notes)),
      ],
    );
  }

  Widget _buildLoadedState(List<Folder> folders, List<SpaceFile> notes) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    final viewMode = ref.watch(folderBrowserViewModeProvider);

    return KeyboardDismissOnScroll(
      child: CustomScrollView(
        slivers: [
          if (folders.isNotEmpty && viewMode == FolderBrowserViewMode.list)
            SliverList.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) => _buildFolderItem(folders[index]),
            ),
          if (folders.isNotEmpty && viewMode == FolderBrowserViewMode.grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              sliver: SliverToBoxAdapter(
                child: FolderCardGrid(
                  folders: folders,
                  onTap: (folder) => _onFolderTap(context, folder),
                  onLongPress: (folder) =>
                      FileTypeRegistry.isProtectedPath(folder.path)
                          ? null
                          : NotesListDialogs.showFolderContextMenu(
                              context, ref, folder),
                  contextMenuItems: (folder) =>
                      FavouriteFolderMenu.items(ref, folder),
                  onContextMenuSelected: (folder, value) =>
                      FavouriteFolderMenu.onSelected(ref, folder)?.call(value),
                ),
              ),
            ),
          if (notes.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
              sliver: SliverToBoxAdapter(
                child: StaggeredFileGrid(
                  files: notes,
                  onTap: (file) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    ref.read(folderSearchQueryProvider.notifier).state = '';
                    if (PlatformUtils.isDesktopLayout(context)) {
                      _openNoteOnDesktop(context, file);
                    } else {
                      context.go('/notes/note/${file.id}');
                    }
                  },
                  onLongPress: (file) {
                    if (FileTypeRegistry.forFile(file).hasContextActions) {
                      NotesListDialogs.showNoteContextMenu(context, ref, file);
                    }
                  },
                ),
              ),
            )
          else
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_outlined,
            size: 48,
            color: SpaceNotesTheme.dim,
          ),
          const SizedBox(height: 20),
          const Text(
            'no notes found',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.muted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _createQuickNote,
            style: TextButton.styleFrom(
              foregroundColor: SpaceNotesTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
                side: const BorderSide(color: SpaceNotesTheme.hairlineStrong),
              ),
            ),
            child: const Text(
              'CREATE FIRST NOTE',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 48,
            color: SpaceNotesTheme.dim,
          ),
          const SizedBox(height: 20),
          Text(
            'no results for "$query"',
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(Folder folder) {
    return FolderListItem(
      key: ValueKey(folder.path),
      folder: folder,
      tall: widget.tallFolderRows,
      onTap: () => _onFolderTap(context, folder),
      onLongPress: FileTypeRegistry.isProtectedPath(folder.path)
          ? null
          : () => NotesListDialogs.showFolderContextMenu(context, ref, folder),
      onMove: FileTypeRegistry.isProtectedPath(folder.path)
          ? null
          : () => NotesListDialogs.showMoveFolderDialog(context, ref, folder),
      onDelete: FileTypeRegistry.isProtectedPath(folder.path)
          ? null
          : () =>
              NotesListDialogs.showDeleteFolderConfirmation(context, ref, folder),
      contextMenuItems: FavouriteFolderMenu.items(ref, folder),
      onContextMenuSelected: FavouriteFolderMenu.onSelected(ref, folder),
    );
  }

  void _onFolderTap(BuildContext context, Folder folder) {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    if (PlatformUtils.isDesktopLayout(context)) {
      ref.read(middlePaneModeProvider.notifier).state =
          MiddlePaneMode.browse(folder.path);
    } else {
      final encodedPath = Uri.encodeComponent(folder.path);
      context.go('/notes/folder/$encodedPath');
    }
  }

  void _openNoteOnDesktop(BuildContext context, SpaceFile file) {
    final parentFolderPath = file.folderPath.endsWith('/')
        ? file.folderPath.substring(0, file.folderPath.length - 1)
        : file.folderPath;
    context.read<DesktopNotesBloc>().add(
          OpenNote(file.id, parentFolderPath: parentFolderPath),
        );
    ref.read(middlePaneModeProvider.notifier).state =
        MiddlePaneMode.fileViewer(file.id);
  }

  Future<void> _createQuickNote() async {
    final String notePath;
    if (widget.folderPath.isEmpty) {
      notePath = 'All Notes/${FileTypeRegistry.defaultNewFileName()}';
    } else {
      final folderPathWithSlash = widget.folderPath.endsWith('/')
          ? widget.folderPath
          : '${widget.folderPath}/';
      notePath = '$folderPathWithSlash${FileTypeRegistry.defaultNewFileName()}';
    }

    final repo = ref.read(notesRepositoryProvider);
    final noteId = await repo.createNote(notePath, '');
    if (noteId == null || !mounted) return;
    if (PlatformUtils.isDesktopLayout(context)) {
      final folderPathWithoutSlash = notePath.contains('/')
          ? notePath.substring(0, notePath.lastIndexOf('/'))
          : '';
      context.read<DesktopNotesBloc>().add(
            OpenNote(noteId, parentFolderPath: folderPathWithoutSlash),
          );
      ref.read(middlePaneModeProvider.notifier).state =
          MiddlePaneMode.fileViewer(noteId);
    } else {
      context.go('/notes/note/$noteId');
    }
  }
}

class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(folderBrowserViewModeProvider);

    Widget button(FolderBrowserViewMode target, IconData icon) {
      final isActive = mode == target;
      return GestureDetector(
        onTap: () =>
            ref.read(folderBrowserViewModeProvider.notifier).state = target,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? SpaceNotesTheme.accent : SpaceNotesTheme.dim,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(FolderBrowserViewMode.list, Icons.view_list_outlined),
        button(FolderBrowserViewMode.grid, Icons.grid_view_outlined),
      ],
    );
  }
}
