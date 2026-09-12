import '../platform/capabilities.dart';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
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
import '../widgets/folder_grid_card.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';
import '../widgets/staggered_file_grid.dart';
import '../file_types/file_type_registry.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../widgets/desktop/content_actions_fab.dart';
import '../widgets/folder_status_bar.dart';
import '../providers/file_transfer_providers.dart';
import '../providers/upload_progress_providers.dart';
import '../services/debug_logger.dart';
import '../services/folder_upload.dart';
import '../providers/file_selection_provider.dart';
import '../widgets/file_selection_bar.dart';
import '../services/bulk_file_actions.dart';
import '../dialogs/bulk_action_dialogs.dart';

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
  bool _isDropTarget = false;

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDropTarget = false);

    final files = <File>[];
    for (final item in details.files) {
      final file = File(item.path);
      if (await FileSystemEntity.isDirectory(item.path)) {
        debugLogger.info('UPLOAD', 'Skipped dropped directory', item.path);
        continue;
      }
      if (await file.exists()) files.add(file);
    }
    if (files.isEmpty || !mounted) return;

    final targetFolder =
        widget.folderPath.isEmpty ? 'All Notes' : widget.folderPath;

    final result = await uploadFilesToFolder(
      service: ref.read(fileTransferServiceProvider),
      batch: ref.read(uploadBatchProvider.notifier),
      folderPath: targetFolder,
      files: files,
    );

    if (!mounted || !result.hasSkipped) return;
    showUploadSkippedDialog(context, result.skipped);
  }

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
        // Ticks belong to the folder they were made in; carrying them into a
        // new folder would aim a bulk action at files no longer on screen.
        ref.read(fileSelectionProvider.notifier).exit();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dynamicFolderContentsProvider(widget.folderPath));
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    if (!Capabilities.canDropFiles) return _buildBody(context, data, isDesktop);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDropTarget = true),
      onDragExited: (_) => setState(() => _isDropTarget = false),
      onDragDone: _handleDrop,
      child: Container(
        foregroundDecoration: _isDropTarget
            ? BoxDecoration(
                border: Border.all(
                  color: SpaceNotesTheme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
                color: SpaceNotesTheme.accent.withValues(alpha: 0.03),
              )
            : null,
        child: _buildBody(context, data, isDesktop),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ({List<Folder> folders, List<SpaceFile> notes}) data,
    bool isDesktop,
  ) {
    final selection = ref.watch(fileSelectionProvider);

    return Column(
      children: [
        if (widget.folderPath.isNotEmpty)
          FolderStatusBar(
            folderPath: widget.folderPath,
            trailing: selection.active
                ? FileSelectionControls(
                    files: data.notes,
                    onDelete: () => _bulkDelete(context, data.notes),
                    onMove: () => _bulkMove(context, data.notes),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [FileSelectToggle(), FileSortToggle()],
                  ),
          ),
        Expanded(
          child: Stack(
            children: [
              _buildLoadedState(data.folders, data.notes),
              if (isDesktop)
                Positioned(
                  right: 14,
                  bottom: 15,
                  child: ContentActionsFab(folderPath: widget.folderPath),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedState(List<Folder> folders, List<SpaceFile> notes) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    final selection = ref.watch(fileSelectionProvider);
    final selectionActive = selection.active;
    final selectedIds = selection.selectedIds;

    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    return KeyboardDismissOnScroll(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: CustomScrollView(
          slivers: [
            if (folders.isNotEmpty)
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
                        FavouriteFolderMenu.onSelected(ref, folder)
                            ?.call(value),
                  ),
                ),
              ),
            if (notes.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
                sliver: StaggeredFileGrid(
                  files: notes,
                  selectedIds: selectedIds,
                  onTap: (file) {
                    if (selectionActive) {
                      ref.read(fileSelectionProvider.notifier).toggle(file.id);
                      return;
                    }
                    FocusManager.instance.primaryFocus?.unfocus();
                    ref.read(folderSearchQueryProvider.notifier).state = '';
                    if (PlatformUtils.isDesktopLayout(context)) {
                      _openNoteOnDesktop(context, file);
                    } else {
                      context.go('/notes/note/${file.id}');
                    }
                  },
                  onLongPress: (file) {
                    if (selectionActive) return;
                    if (FileTypeRegistry.forFile(file).hasContextActions) {
                      NotesListDialogs.showNoteContextMenu(context, ref, file);
                    }
                  },
                ),
              )
            else
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  List<SpaceFile> _selectedFiles(List<SpaceFile> notes) {
    final ids = ref.read(fileSelectionProvider).selectedIds;
    return notes.where((n) => ids.contains(n.id)).toList();
  }

  Future<void> _bulkDelete(BuildContext context, List<SpaceFile> notes) async {
    final files = _selectedFiles(notes);
    if (files.isEmpty) return;

    final confirmed = await BulkActionDialogs.confirmDelete(context, files);
    if (!confirmed || !context.mounted) return;

    final result = await deleteFiles(
      ref.read(notesRepositoryProvider),
      files,
    );

    ref.read(fileSelectionProvider.notifier).exit();
    if (context.mounted) BulkActionDialogs.reportResult(context, 'Deleted', result);
  }

  Future<void> _bulkMove(BuildContext context, List<SpaceFile> notes) async {
    final files = _selectedFiles(notes);
    if (files.isEmpty) return;

    final target = await BulkActionDialogs.pickFolder(context, ref, files.length);
    if (target == null || !context.mounted) return;

    final result = await moveFiles(
      ref.read(notesRepositoryProvider),
      files,
      target,
    );

    ref.read(fileSelectionProvider.notifier).exit();
    if (context.mounted) BulkActionDialogs.reportResult(context, 'Moved', result);
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
