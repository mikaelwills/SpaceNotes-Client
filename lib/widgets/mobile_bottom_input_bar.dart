import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
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
    final isChat = viewType == HomeViewType.chat || viewType == HomeViewType.sessionChat;

    final searchQuery = ref.watch(folderSearchQueryProvider);
    if (!isChat && searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.clear();
      });
    }
    final folderPath = ref.watch(currentFolderPathProvider);
    final notePath = ref.watch(currentNotePathProvider);

    return Stack(
      children: [
        _buildGradientBackground(),
        _buildInputRow(
          viewType: viewType,
          isChat: isChat,
          folderPath: folderPath,
          notePath: notePath,
        ),
      ],
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
  }) {
    if (viewType == HomeViewType.note ||
        viewType == HomeViewType.sessions) {
      return const SizedBox.shrink();
    }

    final location = GoRouterState.of(context).uri.toString();
    if (location == '/settings') {
      return const SizedBox.shrink();
    }

    final isSessionChat = viewType == HomeViewType.sessionChat;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isSessionChat) ...[
            _buildRoundedButton(
              onPressed: () => context.pop(),
              tooltip: 'Back',
              icon: Icons.arrow_back,
            ),
            const SizedBox(width: 8),
          ],
          _buildSearchBar(isChat || isSessionChat),
          const SizedBox(width: 8),
          _buildRightButtons(isChat || isSessionChat, folderPath),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isChat) {
    final chatState = GetIt.I<ChatBloc>().state;
    final targetSession = chatState is ChatReady ? chatState.targetSession : 'note-assistant';

    String hintText;
    if (!isChat) {
      hintText = 'Search notes...';
    } else if (_getCurrentSessionId() != null) {
      hintText = '${_getCurrentSessionId()}...';
    } else {
      hintText = '$targetSession...';
    }

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: SpaceNotesTheme.inputSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: NotesSearchBar(
              controller: _searchController,
              height: 48,
              hintText: hintText,
              onChanged: isChat ? (_) {} : _onSearchChanged,
              onFocusChanged: (focused) {
                setState(() => _isSearchFocused = focused);
              },
              onSubmitted: _onSendToAi,
              showImagePicker: isChat,
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
        ],
      ),
    );
  }

  Widget _buildRightButtons(bool isChat, String folderPath) {
    if (isChat) {
      return _buildRoundedButton(
        onPressed: _onSendToAi,
        tooltip: 'Send to AI',
        icon: Icons.arrow_upward,
      );
    } else if (_isSearchFocused || _searchController.text.isNotEmpty) {
      return _buildRoundedButton(
        onPressed: _onSendToAi,
        tooltip: 'Send to AI',
        icon: Icons.arrow_upward,
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoundedButton(
            onPressed: () => NotesListDialogs.showCreateFolderDialog(
              context,
              ref,
              currentPath: folderPath,
            ),
            tooltip: 'Create new folder',
            icon: Icons.create_new_folder_outlined,
          ),
          const SizedBox(width: 8),
          _buildRoundedButton(
            onPressed: () => _createQuickNote(folderPath),
            tooltip: 'Create new note',
            icon: Icons.add,
          ),
        ],
      );
    }
  }


  Widget _buildRoundedButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(14),
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
    if (l == '/notes/sessions') return HomeViewType.sessions;
    if (l.startsWith('/notes/sessions/')) return HomeViewType.sessionChat;
    return HomeViewType.folders;
  }

  String? _getCurrentSessionId() {
    final l = GoRouterState.of(context).uri.toString();
    if (!l.startsWith('/notes/sessions/')) return null;
    final encoded = l.substring('/notes/sessions/'.length);
    return Uri.decodeComponent(encoded);
  }

  void _onSearchChanged(String query) {
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _onSendToAi() {
    final message = _searchController.text.trim();
    if (message.isEmpty && _pendingImageBase64 == null) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final sessionId = _getCurrentSessionId();
    if (sessionId != null) {
      GetIt.I<ChatBloc>().add(SendSessionMessage(sessionId, message));
      _searchController.clear();
      setState(() {
        _pendingImageBase64 = null;
        _pendingImageMimeType = null;
      });
      return;
    }

    GetIt.I<ChatBloc>().add(SendChatMessage(
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
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      var bytes = await compute(_readFileBytes, image.path);

      final extension = image.path.split('.').last.toLowerCase();
      var mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      if (bytes.length > 4 * 1024 * 1024) {
        bytes = await compute(_compressImage, bytes);
        mimeType = 'image/jpeg';
      }

      setState(() {
        _pendingImageBase64 = base64Encode(bytes);
        _pendingImageMimeType = mimeType;
      });
    } catch (e) {
      debugPrint('[MobileBottomInputBar] Error picking image: $e');
    }
  }

  static Uint8List _compressImage(Uint8List bytes) {
    final img = image_lib.decodeImage(bytes);
    if (img == null) return bytes;

    var resized = img;
    if (img.width > 2048 || img.height > 2048) {
      resized = image_lib.copyResize(img, width: img.width > img.height ? 2048 : -1, height: img.height >= img.width ? 2048 : -1);
    }

    for (final quality in [90, 80, 70, 60]) {
      final jpeg = Uint8List.fromList(image_lib.encodeJpg(resized, quality: quality));
      if (jpeg.length <= 4 * 1024 * 1024) return jpeg;
    }

    return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 50));
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
        debugPrint('[MobileBottomInputBar] Navigating to /notes/note/$noteId');
        context.go('/notes/note/$noteId');
      } else {
        debugPrint('[MobileBottomInputBar] noteId is null or widget not mounted');
      }
    } catch (e, stack) {
      debugPrint('[MobileBottomInputBar] Error creating note: $e');
      debugPrint('[MobileBottomInputBar] Stack trace: $stack');
    }
  }

}
