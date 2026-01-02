import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/connection_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
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
    final viewType = _getCurrentViewType();
    final isChat = viewType == HomeViewType.chat;

    final searchQuery = ref.watch(folderSearchQueryProvider);
    if (!isChat && searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.clear();
      });
    }
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
    if (viewType == HomeViewType.note) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBackButton(viewType, folderPath),
          if (viewType == HomeViewType.chat || folderPath.isNotEmpty)
            const SizedBox(width: 12),
          _buildSearchBar(isChat),
          const SizedBox(width: 12),
          _buildRightButtons(isChat, isWorking, folderPath),
        ],
      ),
    );
  }

  Widget _buildBackButton(HomeViewType viewType, String folderPath) {
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
    debugPrint('[MobileBottomInputBar] _createQuickNote called, folderPath: "$folderPath"');
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    final basePath = folderPath.isEmpty ? 'All Notes' : folderPath;
    final notePath = '$basePath/Untitled-$timestamp.md';
    debugPrint('[MobileBottomInputBar] Creating note at path: "$notePath"');

    final repo = ref.read(notesRepositoryProvider);
    try {
      debugPrint('[MobileBottomInputBar] Calling repo.createNote...');
      final noteId = await repo.createNote(notePath, '');
      debugPrint('[MobileBottomInputBar] repo.createNote returned: $noteId');
      if (noteId != null && mounted) {
        final encodedPath = notePath.split('/').map(Uri.encodeComponent).join('/');
        debugPrint('[MobileBottomInputBar] Navigating to /notes/note/$encodedPath');
        context.go('/notes/note/$encodedPath');
      } else {
        debugPrint('[MobileBottomInputBar] noteId is null or widget not mounted');
      }
    } catch (e, stack) {
      debugPrint('[MobileBottomInputBar] Error creating note: $e');
      debugPrint('[MobileBottomInputBar] Stack trace: $stack');
    }
  }

}
