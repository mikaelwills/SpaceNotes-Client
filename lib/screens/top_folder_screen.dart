import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/terminal_message.dart';

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
  // 1. CONSTANTS
  static const Color _inputAreaBackgroundColor = SpaceNotesTheme.inputSurface;

  // 2. STATE
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isSearchFocused = false;
  bool _showScrollToBottom = false;

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
    _chatScrollController.dispose();
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
    final isAiChatMode = ref.watch(isAiChatModeProvider);

    return Stack(
      children: [
        // Scrollable content layer (fills entire stack)
        Positioned.fill(
          child: isAiChatMode
              ? Column(
                  children: [
                    const ConnectionStatusRow(),
                    Expanded(child: _buildChatMessagesArea()),
                  ],
                )
              : _buildFoldersList(showRecentNotes: isRootLevel),
        ),
        // Bottom input overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomInputArea(),
        ),
      ],
    );
  }

  // 4. WIDGET FUNCTIONS
  Widget _buildBottomInputArea() {
    final isAiChatMode = ref.watch(isAiChatModeProvider);

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isWorking = chatState is ChatSendingMessage ||
            (chatState is ChatReady && chatState.isStreaming);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button - only show when in AI mode
              if (isAiChatMode)
                _buildCircularButton(
                  onPressed: _exitAiChatMode,
                  tooltip: 'Exit AI chat',
                  icon: Icons.arrow_back,
                ),
              if (isAiChatMode) const SizedBox(width: 12),
              // Search/input field with rounded background
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _inputAreaBackgroundColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: NotesSearchBar(
                    controller: _searchController,
                    height: 48,
                    hintText: isAiChatMode ? 'Ask AI...' : 'Search notes...',
                    onChanged: isAiChatMode ? (_) {} : _onSearchChanged,
                    onFocusChanged: (focused) {
                      setState(() => _isSearchFocused = focused);
                    },
                    onSubmitted: _onSendToAi,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // In AI mode: show cancel when working, send when not
              if (isAiChatMode) ...[
                if (isWorking)
                  _buildCircularButton(
                    onPressed: () =>
                        context.read<ChatBloc>().add(CancelCurrentOperation()),
                    tooltip: 'Cancel',
                    icon: Icons.stop,
                  )
                else
                  _buildCircularButton(
                    onPressed: _onSendToAi,
                    tooltip: 'Send to AI',
                    icon: Icons.arrow_upward,
                  ),
              ]
              // Not in AI mode: show send when focused, otherwise create buttons
              else if (_isSearchFocused) ...[
                _buildCircularButton(
                  onPressed: _onSendToAi,
                  tooltip: 'Send to AI',
                  icon: Icons.arrow_upward,
                ),
              ] else ...[
                // Create folder button
                _buildCircularButton(
                  onPressed: () => NotesListDialogs.showCreateFolderDialog(
                    context,
                    ref,
                    currentPath: widget.folderPath,
                  ),
                  tooltip: 'Create new folder',
                  icon: Icons.create_new_folder_outlined,
                ),
                const SizedBox(width: 8),
                // Add note button
                _buildCircularButton(
                  onPressed: _createQuickNote,
                  tooltip: 'Create new note',
                  icon: Icons.edit_outlined,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _inputAreaBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(
          icon,
          size: 24,
          color: SpaceNotesTheme.primary,
        ),
      ),
    );
  }

  Widget _buildChatMessagesArea() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        // Auto-scroll to bottom when new messages arrive or streaming
        if (state is ChatReady || state is ChatSendingMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_chatScrollController.hasClients) {
              _chatScrollController.animateTo(
                _chatScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      builder: (context, state) {
        final messages = state is ChatReady
            ? state.messages
            : state is ChatSendingMessage
                ? state.messages
                : <dynamic>[];
        final isStreaming = state is ChatReady ? state.isStreaming : false;

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Ask me anything...',
              style: SpaceNotesTextStyles.terminal,
            ),
          );
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final isNearBottom = _chatScrollController.position.pixels >=
                      _chatScrollController.position.maxScrollExtent - 100;
                  if (_showScrollToBottom == isNearBottom) {
                    setState(() => _showScrollToBottom = !isNearBottom);
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isLastMessage = index == messages.length - 1;
                  final isStreamingMessage = isStreaming && isLastMessage;

                  return TerminalMessage(
                    message: message,
                    isStreaming: isStreamingMessage,
                  );
                },
              ),
            ),
            if (_showScrollToBottom) _buildScrollToBottomButton(),
          ],
        );
      },
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: _inputAreaBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          },
          tooltip: 'Scroll to bottom',
          icon: const Icon(
            Icons.arrow_downward,
            size: 24,
            color: SpaceNotesTheme.primary,
          ),
        ),
      ),
    );
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

  Widget _buildLoadedState(
    List<Folder> folders,
    List<Note> notes,
    bool showRecentNotes,
  ) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    // Handle empty search results
    if (searchQuery.trim().isNotEmpty && folders.isEmpty && notes.isEmpty) {
      return _buildNoSearchResultsState(searchQuery);
    }

    // Handle general empty state (no search, no folders)
    if (folders.isEmpty && notes.isEmpty && !showRecentNotes) {
      return _buildEmptyState();
    }

    // Build combined list: folders first, then notes (only shown during search)
    final totalItems = folders.length + notes.length;

    return CustomScrollView(
      slivers: [
        // Recent notes grid at top (only on root level)
        if (showRecentNotes)
          const SliverToBoxAdapter(
            child: RecentNotesGrid(),
          ),
        // Folders and notes list
        if (totalItems > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
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
        // Empty state when only showing recent notes
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

  void _onSendToAi() {
    final message = _searchController.text.trim();
    if (message.isEmpty) return;

    // Enter AI chat mode and send the message
    ref.read(isAiChatModeProvider.notifier).state = true;

    // Send message to ChatBloc
    context.read<ChatBloc>().add(SendChatMessage(message));

    // Clear the search field
    _searchController.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
  }

  void _exitAiChatMode() {
    ref.read(isAiChatModeProvider.notifier).state = false;
  }
}
