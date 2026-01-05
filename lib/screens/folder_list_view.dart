import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../generated/folder.dart';
import '../generated/note.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/note_list_item.dart';
import '../dialogs/notes_list_dialogs.dart';

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
    final combinedAsync =
        ref.watch(dynamicFolderContentsProvider(widget.folderPath));

    return combinedAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorMessage(error.toString()),
      data: (data) => _buildLoadedState(data.folders, data.notes),
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

  Widget _buildLoadedState(List<Folder> folders, List<Note> notes) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    final totalItems = folders.length + notes.length;
    final isRootLevel = widget.folderPath.isEmpty;
    final headerOffset = isRootLevel ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: totalItems + headerOffset,
      itemBuilder: (context, index) {
        if (isRootLevel && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Recent',
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 12,
                    color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }
        final itemIndex = index - headerOffset;
        if (itemIndex < folders.length) {
          return _buildFolderItem(folders[itemIndex]);
        } else {
          return _buildNoteItem(notes[itemIndex - folders.length]);
        }
      },
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
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(folderSearchQueryProvider.notifier).state = '';
        final encodedPath = Uri.encodeComponent(folder.path);
        context.go('/notes/folder/$encodedPath');
      },
      onLongPress: () =>
          NotesListDialogs.showFolderContextMenu(context, ref, folder),
      onMove: () => NotesListDialogs.showMoveFolderDialog(context, ref, folder),
      onDelete: () =>
          NotesListDialogs.showDeleteFolderConfirmation(context, ref, folder),
    );
  }

  Widget _buildNoteItem(Note note) {
    return NoteListItem(
      key: ValueKey(note.id),
      note: note,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(folderSearchQueryProvider.notifier).state = '';
        final encodedPath =
            note.path.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedPath');
      },
      onLongPress: () =>
          NotesListDialogs.showNoteContextMenu(context, ref, note),
      onMove: () => NotesListDialogs.showMoveNoteDialog(context, ref, note),
      onDelete: () =>
          NotesListDialogs.showDeleteNoteConfirmation(context, ref, note),
    );
  }

  Future<void> _createQuickNote() async {
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

    final repo = ref.read(notesRepositoryProvider);
    final noteId = await repo.createNote(notePath, '');
    if (noteId != null && mounted) {
      final encodedPath =
          notePath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/note/$encodedPath');
    }
  }
}
