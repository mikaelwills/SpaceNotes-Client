import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../generated/folder.dart';
import '../generated/note.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/note_list_item.dart';
import '../widgets/recent_notes_grid.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/terminal_message.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import 'home_screen.dart';

/// FolderListView displays folder contents and handles AI chat display
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
  final ScrollController _chatScrollController = ScrollController();
  bool _showScrollToBottom = false;

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
  void dispose() {
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRootLevel = widget.folderPath.isEmpty;
    final isAiChatMode = ref.watch(isAiChatModeProvider);

    if (isAiChatMode) {
      return Column(
        children: [
          const ConnectionStatusRow(),
          Expanded(child: _buildChatMessagesArea()),
        ],
      );
    }

    return _buildFoldersList(showRecentNotes: isRootLevel);
  }

  Widget _buildChatMessagesArea() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
      bottom: 100,
      right: 16,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: SpaceNotesTheme.inputSurface,
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
