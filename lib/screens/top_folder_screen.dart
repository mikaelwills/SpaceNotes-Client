import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/folder.dart';
import '../generated/note.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/note_list_item.dart';
import '../widgets/notes_search_bar.dart';
import '../widgets/recent_notes_grid.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../router/app_router.dart';

class TopFolderListScreen extends ConsumerStatefulWidget {
  final String folderPath;

  const TopFolderListScreen({
    super.key,
    this.folderPath = '', // Empty string = root/top level
  });

  @override
  ConsumerState<TopFolderListScreen> createState() =>
      _TopFolderListScreenState();
}

class _TopFolderListScreenState extends ConsumerState<TopFolderListScreen>
    with RouteAware {
  // 1. CONSTRUCTOR
  final TextEditingController _searchController = TextEditingController();

  // 2. INIT
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  // Called when THIS screen is pushed onto the navigation stack
  @override
  void didPush() {
    print('✅ didPush: TopFolderScreen pushed - clearing search');
    // Delay modification until after build phase
    Future(() {
      if (mounted) {
        _searchController.clear();
        ref.read(folderSearchQueryProvider.notifier).state = '';
      }
    });
  }

  // Called when a route is popped and we return to THIS screen
  @override
  void didPopNext() {
    print('✅ didPopNext: Returned to TopFolderScreen - clearing search');
    // Delay modification until after build phase
    Future(() {
      if (mounted) {
        _searchController.clear();
        ref.read(folderSearchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  void didPop() {
    print('📍 didPop: TopFolderScreen popped');
  }

  @override
  void didPushNext() {
    print('📍 didPushNext: New route pushed on top of TopFolderScreen');
  }

  // 3. BUILD
  @override
  Widget build(BuildContext context) {
    // Only show recent notes grid at root level
    final isRootLevel = widget.folderPath.isEmpty;

    return Column(
      children: [
        if (isRootLevel) const RecentNotesGrid(),
        _buildFoldersList(),
        _buildBottomInputArea(),
      ],
    );
  }

  // 4. WIDGET FUNCTIONS
  Widget _buildBottomInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Back button (left side)
          IconButton(
            onPressed: _navigateBack,
            tooltip: 'Back',
            icon: const Icon(
              size: 30,
              Icons.arrow_back,
              color: SpaceNotesTheme.primary,
            ),
          ),
          Expanded(
            child: NotesSearchBar(
              controller: _searchController,
              height: 56,
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Create folder button (right)
          IconButton(
            onPressed: () => NotesListDialogs.showCreateFolderDialog(
              context,
              ref,
              currentPath: widget.folderPath,
            ),
            tooltip: 'Create new folder',
            icon: const Icon(
              size: 30,
              Icons.create_new_folder_outlined,
              color: SpaceNotesTheme.primary,
            ),
          ),
          // Add note button (right)
          IconButton(
            onPressed: _createQuickNote,
            tooltip: 'Create new note',
            icon: const Icon(
              size: 30,
              Icons.add,
              color: SpaceNotesTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersList() {
    final combinedAsync =
        ref.watch(dynamicFolderContentsProvider(widget.folderPath));

    return Expanded(
      child: combinedAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorMessage(error.toString()),
        data: (data) => _buildLoadedState(data.folders, data.notes),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          SpaceNotesTheme.primary,
        ),
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

    // Handle empty search results
    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    // Handle general empty state (no search, no folders)
    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    // Build combined list: folders first, then notes (only shown during search)
    final totalItems = folders.length + notes.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return _buildFolderItem(folders[index]);
        } else {
          return _buildNoteItem(notes[index - folders.length]);
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
        print('📁 Folder tapped: ${folder.path}');
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
        final encodedPath = Uri.encodeComponent(note.path);
        context.go('/notes/$encodedPath');
      },
      onLongPress: () =>
          NotesListDialogs.showNoteContextMenu(context, ref, note),
    );
  }

  // 5. HELPER FUNCTIONS
  void _createQuickNote() {
    // Generate timestamp-based filename
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    // Create note in current folder (or "All Notes" if at root)
    final String notePath;
    if (widget.folderPath.isEmpty) {
      // At root: create in "All Notes" folder
      notePath = 'All Notes/Untitled-$timestamp.md';
    } else {
      // Inside a folder: create note in current folder
      final folderPathWithSlash = widget.folderPath.endsWith('/')
          ? widget.folderPath
          : '${widget.folderPath}/';
      notePath = '${folderPathWithSlash}Untitled-$timestamp.md';
    }

    print('📝 Creating note in current folder: $notePath');

    // Navigate directly to note screen without dialog
    final encodedPath = Uri.encodeComponent(notePath);
    context.go('/notes/$encodedPath?new=true');
  }

  void _onSearchChanged(String query) {
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _navigateBack() {
    if (widget.folderPath == null || widget.folderPath!.isEmpty) {
      // At root, go to chat
      context.go('/chat');
      return;
    }

    // Parse parent folder path
    final parts = widget.folderPath!.split('/');
    if (parts.length <= 1) {
      // Go to notes root
      context.go('/notes');
    } else {
      // Go to parent folder
      final parentPath = parts.sublist(0, parts.length - 1).join('/');
      context.go('/notes/folder/$parentPath');
    }
  }
}
