import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/note_list_item.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';
import '../file_types/file_type_registry.dart';

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
    final data = ref.watch(dynamicFolderContentsProvider(widget.folderPath));
    return _buildLoadedState(data.folders, data.notes);
  }

  Widget _buildLoadedState(List<Folder> folders, List<SpaceFile> notes) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    final totalItems = folders.length + notes.length;

    return KeyboardDismissOnScroll(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index < folders.length) {
            return _buildFolderItem(folders[index]);
          } else {
            final noteIndex = index - folders.length;
            return _buildNoteItem(notes[noteIndex], noteIndex + 1);
          }
        },
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
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(folderSearchQueryProvider.notifier).state = '';
        final encodedPath = Uri.encodeComponent(folder.path);
        context.go('/notes/folder/$encodedPath');
      },
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
    );
  }

  Widget _buildNoteItem(SpaceFile note, int index) {
    return NoteListItem(
      key: ValueKey(note.id),
      note: note,
      index: index,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(folderSearchQueryProvider.notifier).state = '';
        context.go('/notes/note/${note.id}');
      },
      onLongPress: FileTypeRegistry.forFile(note).hasContextActions
          ? () => NotesListDialogs.showNoteContextMenu(context, ref, note)
          : null,
      onMove: FileTypeRegistry.forFile(note).isMovable
          ? () => NotesListDialogs.showMoveNoteDialog(context, ref, note)
          : null,
      onDelete: FileTypeRegistry.forFile(note).isDeletable
          ? () => NotesListDialogs.showDeleteNoteConfirmation(context, ref, note)
          : null,
    );
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
    if (noteId != null && mounted) {
      context.go('/notes/note/$noteId');
    }
  }
}
