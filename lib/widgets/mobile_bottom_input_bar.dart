import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../generated/note.dart';
import '../screens/home_screen.dart';
import 'notes_search_bar.dart';

Future<Uint8List> _readFileBytes(String path) async {
  return File(path).readAsBytes();
}

class MobileBottomInputBar extends ConsumerStatefulWidget {
  const MobileBottomInputBar({super.key});

  @override
  ConsumerState<MobileBottomInputBar> createState() => _MobileBottomInputBarState();
}

class _MobileBottomInputBarState extends ConsumerState<MobileBottomInputBar> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSearchFocused = false;
  String? _pendingImageBase64;
  String? _pendingImageMimeType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    if (searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.clear();
      });
    }
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
            _buildGradientBackground(),
            _buildInputRow(
              viewType: viewType,
              isChat: isChat,
              folderPath: folderPath,
              notePath: notePath,
              isWorking: isWorking,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGradientBackground() {
    return Positioned.fill(
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
    );
  }

  Widget _buildInputRow({
    required HomeViewType viewType,
    required bool isChat,
    required String folderPath,
    required String? notePath,
    required bool isWorking,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBackButton(viewType, folderPath),
          if (viewType == HomeViewType.chat ||
              viewType == HomeViewType.note ||
              folderPath.isNotEmpty)
            const SizedBox(width: 12),
          if (viewType == HomeViewType.note)
            ..._buildNoteActions(notePath)
          else ...[
            _buildSearchBar(isChat),
            const SizedBox(width: 12),
            _buildRightButtons(isChat, isWorking, folderPath),
          ],
        ],
      ),
    );
  }

  Widget _buildBackButton(HomeViewType viewType, String folderPath) {
    if (viewType == HomeViewType.chat) {
      return _buildCircularButton(
        onPressed: _exitChat,
        tooltip: 'Exit AI chat',
        icon: Icons.arrow_back,
      );
    } else if (viewType == HomeViewType.note) {
      return _buildCircularButton(
        onPressed: _navigateBackFromNote,
        tooltip: 'Go back',
        icon: Icons.arrow_back,
      );
    } else if (folderPath.isNotEmpty) {
      return _buildCircularButton(
        onPressed: () => _navigateToParentFolder(folderPath),
        tooltip: 'Go back',
        icon: Icons.arrow_back,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSearchBar(bool isChat) {
    final isOpenCodeConnected = ref.watch(openCodeConnectionProvider).valueOrNull ?? false;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: SpaceNotesTheme.inputSurface,
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
          showImagePicker: isOpenCodeConnected,
          onImagePickerTap: _onPickImage,
          hasImageAttached: _pendingImageBase64 != null,
          onClearImage: () {
            setState(() {
              _pendingImageBase64 = null;
              _pendingImageMimeType = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRightButtons(bool isChat, bool isWorking, String folderPath) {
    final isOpenCodeConnected = ref.watch(openCodeConnectionProvider).valueOrNull ?? false;

    if (isChat) {
      if (!isOpenCodeConnected) {
        return const SizedBox.shrink();
      }
      return isWorking
          ? _buildCircularButton(
              onPressed: () =>
                  context.read<ChatBloc>().add(CancelCurrentOperation()),
              tooltip: 'Cancel',
              icon: Icons.stop,
            )
          : _buildCircularButton(
              onPressed: _onSendToAi,
              tooltip: 'Send to AI',
              icon: Icons.arrow_upward,
            );
    } else if ((_isSearchFocused || _searchController.text.isNotEmpty) && isOpenCodeConnected) {
      return _buildCircularButton(
        onPressed: _onSendToAi,
        tooltip: 'Send to AI',
        icon: Icons.arrow_upward,
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          _buildCircularButton(
            onPressed: () => _createQuickNote(folderPath),
            tooltip: 'Create new note',
            icon: Icons.add,
          ),
        ],
      );
    }
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
        color: SpaceNotesTheme.inputSurface,
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
        color: SpaceNotesTheme.inputSurface,
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

  HomeViewType _getCurrentViewType() {
    final l = GoRouterState.of(context).uri.toString();
    if (l.startsWith('/notes/chat')) return HomeViewType.chat;
    if (l.startsWith('/notes/note/')) return HomeViewType.note;
    return HomeViewType.folders;
  }

  void _exitChat() {
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

    final lastSlash = notePath.lastIndexOf('/');
    if (lastSlash == -1) {
      context.go('/notes');
    } else {
      final folderPath = notePath.substring(0, lastSlash);
      final encodedPath =
          folderPath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/folder/$encodedPath');
    }
    ref.read(currentNotePathProvider.notifier).state = null;
  }

  void _onSearchChanged(String query) {
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _onSendToAi() {
    final message = _searchController.text.trim();
    debugPrint('[MobileBottomInputBar] _onSendToAi called, message: "$message"');
    if (message.isEmpty && _pendingImageBase64 == null) return;

    debugPrint('[MobileBottomInputBar] Sending message and navigating to chat');
    context.read<ChatBloc>().add(SendChatMessage(
      message.isEmpty ? 'What is in this image?' : message,
      imageBase64: _pendingImageBase64,
      imageMimeType: _pendingImageMimeType,
    ));
    context.go('/notes/chat');

    _searchController.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    setState(() {
      _pendingImageBase64 = null;
      _pendingImageMimeType = null;
    });
  }

  Future<void> _onPickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final bytes = await compute(_readFileBytes, image.path);
      final base64 = base64Encode(bytes);

      final extension = image.path.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      setState(() {
        _pendingImageBase64 = base64;
        _pendingImageMimeType = mimeType;
      });
    } catch (e) {
      debugPrint('[MobileBottomInputBar] Error picking image: $e');
    }
  }

  Future<void> _createQuickNote(String folderPath) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    final notePath = 'All Notes/Untitled-$timestamp.md';

    final repo = ref.read(notesRepositoryProvider);
    final noteId = await repo.createNote(notePath, '');
    if (noteId != null && mounted) {
      final encodedPath = notePath.split('/').map(Uri.encodeComponent).join('/');
      context.go('/notes/note/$encodedPath');
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
