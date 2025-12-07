import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../widgets/notes_search_bar.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../generated/note.dart';

/// Enum to track which view is currently active
enum HomeViewType { folders, chat, note }

/// Provider to track the current folder path for bottom bar context
final currentFolderPathProvider = StateProvider<String>((ref) => '');

/// Provider to track if we're viewing a note
final currentNotePathProvider = StateProvider<String?>((ref) => null);

/// HomeScreen shell that provides the shared bottom input area
class HomeScreen extends ConsumerStatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Constants
  static const Color _inputAreaBackgroundColor = SpaceNotesTheme.inputSurface;

  // State
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Determine the current view type based on route
  HomeViewType _getCurrentViewType() {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/notes/chat')) return HomeViewType.chat;
    if (location.startsWith('/notes/note/')) return HomeViewType.note;
    return HomeViewType.folders;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Child content (fills entire area, scrolls under bottom bar)
        Positioned.fill(
          child: widget.child,
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

  Widget _buildBottomInputArea() {
    final viewType = _getCurrentViewType();
    final isChat = viewType == HomeViewType.chat;
    final folderPath = ref.watch(currentFolderPathProvider);
    final notePath = ref.watch(currentNotePathProvider);

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isWorking = chatState is ChatSendingMessage ||
            (chatState is ChatReady && chatState.isStreaming);

        return Stack(
          children: [
            // Gradient background layer
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      SpaceNotesTheme.background,
                    ],
                  ),
                ),
              ),
            ),
            // Input row on top
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button logic
                  if (viewType == HomeViewType.chat)
                    _buildCircularButton(
                      onPressed: _exitAiChatMode,
                      tooltip: 'Exit AI chat',
                      icon: Icons.arrow_back,
                    )
                  else if (viewType == HomeViewType.note)
                    _buildCircularButton(
                      onPressed: () => _navigateBackFromNote(),
                      tooltip: 'Go back',
                      icon: Icons.arrow_back,
                    )
                  else if (folderPath.isNotEmpty)
                    _buildCircularButton(
                      onPressed: () => _navigateToParentFolder(folderPath),
                      tooltip: 'Go back',
                      icon: Icons.arrow_back,
                    ),
                  // Spacer after back button
                  if (viewType == HomeViewType.chat ||
                      viewType == HomeViewType.note ||
                      folderPath.isNotEmpty)
                    const SizedBox(width: 12),
                  // Main content area (search bar or note actions)
                  if (viewType == HomeViewType.note)
                    // Note view: Move and Delete buttons
                    ..._buildNoteActions(notePath)
                  else ...[
                    // Folder/Chat view: Search bar
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _inputAreaBackgroundColor,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: NotesSearchBar(
                          controller: _searchController,
                          height: 48,
                          hintText: isChat ? 'Ask AI...' : 'Search notes...',
                          onChanged: isChat ? (_) {} : _onSearchChanged,
                          onFocusChanged: (focused) {
                            setState(() => _isSearchFocused = focused);
                          },
                          onSubmitted: _onSendToAi,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right side buttons
                    if (isChat) ...[
                      if (isWorking)
                        _buildCircularButton(
                          onPressed: () => context
                              .read<ChatBloc>()
                              .add(CancelCurrentOperation()),
                          tooltip: 'Cancel',
                          icon: Icons.stop,
                        )
                      else
                        _buildCircularButton(
                          onPressed: _onSendToAi,
                          tooltip: 'Send to AI',
                          icon: Icons.arrow_upward,
                        ),
                    ] else if (_isSearchFocused) ...[
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
                          currentPath: folderPath,
                        ),
                        tooltip: 'Create new folder',
                        icon: Icons.create_new_folder_outlined,
                      ),
                      const SizedBox(width: 8),
                      // Add note button
                      _buildCircularButton(
                        onPressed: () => _createQuickNote(folderPath),
                        tooltip: 'Create new note',
                        icon: Icons.edit_outlined,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildNoteActions(String? notePath) {
    return [
      Expanded(
        child: _buildActionButton(
          onPressed: () => _handleMoveNote(notePath),
          icon: Icons.drive_file_move_outlined,
          label: 'Move',
          color: SpaceNotesTheme.primary,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildActionButton(
          onPressed: () => _handleDeleteNote(notePath),
          icon: Icons.delete_outline,
          label: 'Delete',
          color: SpaceNotesTheme.error,
        ),
      ),
    ];
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _inputAreaBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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

  // Navigation helpers
  void _exitAiChatMode() {
    context.go('/notes');
  }

  void _navigateToParentFolder(String currentPath) {
    if (currentPath.isEmpty) return;

    final lastSlash = currentPath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final parentPath = currentPath.substring(0, lastSlash);
      final encodedPath =
          parentPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
  }

  void _navigateBackFromNote() {
    final notePath = ref.read(currentNotePathProvider);
    if (notePath == null) {
      context.go('/notes');
      return;
    }

    // Navigate to the folder containing this note
    final lastSlash = notePath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final folderPath = notePath.substring(0, lastSlash);
      final encodedPath =
          folderPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
    // Clear note path
    ref.read(currentNotePathProvider.notifier).state = null;
  }

  // Search and AI helpers
  void _onSearchChanged(String query) {
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _onSendToAi() {
    final message = _searchController.text.trim();
    if (message.isEmpty) return;

    context.read<ChatBloc>().add(SendChatMessage(message));
    context.go('/notes/chat');

    _searchController.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
  }

  // Note action helpers
  void _createQuickNote(String folderPath) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    final String notePath;
    if (folderPath.isEmpty) {
      notePath = 'All Notes/Untitled-$timestamp.md';
    } else {
      final folderPathWithSlash =
          folderPath.endsWith('/') ? folderPath : '$folderPath/';
      notePath = '${folderPathWithSlash}Untitled-$timestamp.md';
    }

    final encodedPath =
        notePath.split('/').map(Uri.encodeComponent).join('/');
    if (mounted) {
      context.go('/notes/note/$encodedPath?new=true');
    }
  }

  Note? _getCurrentNote(String? notePath) {
    if (notePath == null) return null;
    final notes = ref.read(notesListProvider).valueOrNull;
    return notes?.firstWhereOrNull((n) => n.path == notePath);
  }

  void _handleMoveNote(String? notePath) {
    final note = _getCurrentNote(notePath);
    if (note == null) return;
    NotesListDialogs.showMoveNoteDialog(context, ref, note);
  }

  void _handleDeleteNote(String? notePath) {
    final note = _getCurrentNote(notePath);
    if (note == null) return;

    // Calculate where to navigate after delete
    final String navigateTo;
    if (notePath!.contains('/')) {
      final lastSlash = notePath.lastIndexOf('/');
      final folderPath = notePath.substring(0, lastSlash);
      final encodedFolderPath = Uri.encodeComponent(folderPath);
      navigateTo = '/notes/folder/$encodedFolderPath';
    } else {
      navigateTo = '/notes';
    }

    NotesListDialogs.showDeleteNoteConfirmation(
      context,
      ref,
      note,
      navigateToAfterDelete: navigateTo,
    );
  }
}
