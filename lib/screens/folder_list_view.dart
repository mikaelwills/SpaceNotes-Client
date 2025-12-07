import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../generated/folder.dart';
import '../generated/note.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/note_list_item.dart';
import '../widgets/recent_notes_grid.dart';
import '../dialogs/notes_list_dialogs.dart';
import 'home_screen.dart';

/// FolderListView displays folder contents
/// The bottom input area is provided by the parent HomeScreen shell
class FolderListView extends ConsumerStatefulWidget {
  final String folderPath;

  const FolderListView({
    super.key,
    this.folderPath = '',
  });

  @override
  ConsumerState<FolderListView> createState() => _FolderListViewState();
}

class _FolderListViewState extends ConsumerState<FolderListView> {
  @override
  void initState() {
    super.initState();
    // Update the folder path provider when this view is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentFolderPathProvider.notifier).state = widget.folderPath;
      // Clear note path since we're in folder view
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
    final isRootLevel = widget.folderPath.isEmpty;
    return _buildFoldersList(showRecentNotes: isRootLevel);
  }

  Widget _buildFoldersList({bool showRecentNotes = false}) {
    final combinedAsync =
        ref.watch(dynamicFolderContentsProvider(widget.folderPath));

    return combinedAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorMessage(error.toString()),
      data: (data) =>
          _buildLoadedState(data.folders, data.notes, showRecentNotes),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(SpaceNotesTheme.primary),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: SpaceNotesTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(
    List<Folder> folders,
    List<Note> notes,
    bool showRecentNotes,
  ) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    if (folders.isEmpty && notes.isEmpty && !showRecentNotes) {
      return _buildEmptyState();
    }

    final totalItems = folders.length + notes.length;

    return CustomScrollView(
      slivers: [
        if (showRecentNotes)
          const SliverToBoxAdapter(
            child: RecentNotesGrid(),
          ),
        if (totalItems > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < folders.length) {
                    return _buildFolderItem(folders[index]);
                  } else {
                    return _buildNoteItem(notes[index - folders.length]);
                  }
                },
                childCount: totalItems,
              ),
            ),
          ),
        if (totalItems == 0 && showRecentNotes)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          ),
      ],
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
            color: SpaceNotesTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notes found',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createQuickNote,
            child: const Text('Create first note'),
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
            color: SpaceNotesTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.textSecondary,
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
      onTap: () {
        final encodedPath = Uri.encodeComponent(folder.path);
        context.go('/notes/folder/$encodedPath');
      },
      onLongPress: () =>
          NotesListDialogs.showFolderContextMenu(context, ref, folder),
    );
  }

  Widget _buildNoteItem(Note note) {
    return NoteListItem(
      key: ValueKey(note.id),
      note: note,
      onTap: () {
        final encodedPath =
            note.path.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedPath');
      },
      onLongPress: () =>
          NotesListDialogs.showNoteContextMenu(context, ref, note),
    );
  }

  void _createQuickNote() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    final String notePath;
    if (widget.folderPath.isEmpty) {
      notePath = 'All Notes/Untitled-$timestamp.md';
    } else {
      final folderPathWithSlash = widget.folderPath.endsWith('/')
          ? widget.folderPath
          : '${widget.folderPath}/';
      notePath = '${folderPathWithSlash}Untitled-$timestamp.md';
    }

    final encodedPath =
        notePath.split('/').map(Uri.encodeComponent).join('/');
    context.go('/notes/note/$encodedPath?new=true');
  }
}
