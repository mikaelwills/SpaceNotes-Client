import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../providers/notes_providers.dart';
import '../providers/chat_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../screens/home_screen.dart';
import 'primitives/primitives.dart';

Future<Uint8List> _readFileBytes(String path) async {
  return File(path).readAsBytes();
}

class MobileBottomInputBar extends ConsumerStatefulWidget {
  const MobileBottomInputBar({super.key});

  @override
  ConsumerState<MobileBottomInputBar> createState() =>
      _MobileBottomInputBarState();
}

class _MobileBottomInputBarState extends ConsumerState<MobileBottomInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasText = false;
  bool _isFocused = false;
  Uint8List? _pendingImageBytes;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _getCurrentViewType();

    if (viewType == HomeViewType.note || viewType == HomeViewType.agents) {
      return const SizedBox.shrink();
    }
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/settings') {
      return const SizedBox.shrink();
    }

    final isChat =
        viewType == HomeViewType.chat || viewType == HomeViewType.agentChat;
    final isAgentChat = viewType == HomeViewType.agentChat;

    final searchQuery = ref.watch(folderSearchQueryProvider);
    if (!isChat && searchQuery.isEmpty && _textController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textController.clear();
      });
    }

    final folderPath = ref.watch(currentFolderPathProvider);

    return SafeArea(
      top: false,
      child: SnChatDock(
        controller: _textController,
        focusNode: _focusNode,
        hint: _computeHint(isChat),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        onChanged: isChat ? null : _onSearchChanged,
        onSend: _onSend,
        showSend: isChat || _isFocused || _hasText,
        leading: [
          if (isAgentChat)
            SnDockTile(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
              semanticLabel: 'back',
            ),
        ],
        trailing: _buildTrailing(isChat, folderPath),
      ),
    );
  }

  String _computeHint(bool isChat) {
    if (!isChat) return 'search notes…';
    final aid = _getCurrentAgentId();
    if (aid != null) return aid;
    return ref.read(targetAgentProvider);
  }

  List<Widget> _buildTrailing(bool isChat, String folderPath) {
    if (isChat) {
      final hasImage = _pendingImageBytes != null;
      return [
        SnDockTile(
          icon: hasImage ? Icons.image : Icons.image_outlined,
          onTap: hasImage
              ? () {
                  HapticFeedback.lightImpact();
                  setState(() => _pendingImageBytes = null);
                }
              : _onPickImage,
          semanticLabel: hasImage ? 'remove image' : 'attach image',
        ),
      ];
    }
    if (_isFocused || _hasText) {
      return const [];
    }
    return [
      SnDockTile(
        icon: Icons.create_new_folder_outlined,
        onTap: () => NotesListDialogs.showCreateFolderDialog(
          context,
          ref,
          currentPath: folderPath,
        ),
        semanticLabel: 'new folder',
      ),
      SnDockTile(
        icon: Icons.note_add_outlined,
        onTap: () => _createQuickNote(folderPath),
        semanticLabel: 'new note',
      ),
    ];
  }

  HomeViewType _getCurrentViewType() {
    final l = GoRouterState.of(context).uri.toString();
    if (l.startsWith('/notes/chat')) return HomeViewType.chat;
    if (l.startsWith('/notes/note/')) return HomeViewType.note;
    if (l == '/notes/agents') return HomeViewType.agents;
    if (l.startsWith('/notes/agents/')) return HomeViewType.agentChat;
    return HomeViewType.folders;
  }

  String? _getCurrentAgentId() {
    final l = GoRouterState.of(context).uri.toString();
    if (!l.startsWith('/notes/agents/')) return null;
    final encoded = l.substring('/notes/agents/'.length);
    return Uri.decodeComponent(encoded);
  }

  void _onSearchChanged(String query) {
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _onSend() {
    final message = _textController.text.trim();
    final image = _pendingImageBytes;
    if (message.isEmpty && image == null) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final agentId = _getCurrentAgentId();
    if (agentId != null) {
      if (image != null) {
        sendChatImage(ref, agentId: agentId, caption: message, pngBytes: image);
      } else {
        sendChatMessage(ref, agentId: agentId, text: message);
      }
      _textController.clear();
      setState(() => _pendingImageBytes = null);
      return;
    }

    final targetAgent = ref.read(targetAgentProvider);
    if (image != null) {
      sendChatImage(ref,
          agentId: targetAgent, caption: message, pngBytes: image);
    } else {
      sendChatMessage(ref, agentId: targetAgent, text: message);
    }
    context.go('/notes/chat');

    _textController.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    setState(() => _pendingImageBytes = null);
  }

  Future<void> _onPickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final raw = await compute(_readFileBytes, image.path);
      final png = await compute(_resizeToPng, raw);
      if (png == null) {
        debugPrint('[MobileBottomInputBar] Image decode failed');
        return;
      }
      if (png.length > 2 * 1024 * 1024) {
        debugPrint(
            '[MobileBottomInputBar] Image exceeds 2MB post-compress: ${png.length}');
        return;
      }

      setState(() => _pendingImageBytes = png);
    } catch (e) {
      debugPrint('[MobileBottomInputBar] Error picking image: $e');
    }
  }

  static Uint8List? _resizeToPng(Uint8List bytes) {
    final img = image_lib.decodeImage(bytes);
    if (img == null) return null;

    var resized = img;
    if (img.width > 1024 || img.height > 1024) {
      resized = image_lib.copyResize(img,
          width: img.width >= img.height ? 1024 : -1,
          height: img.height > img.width ? 1024 : -1);
    }

    return Uint8List.fromList(image_lib.encodePng(resized));
  }

  Future<void> _createQuickNote(String folderPath) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final basePath = folderPath.isEmpty ? 'All Notes' : folderPath;
    final notePath = '$basePath/Untitled-$timestamp.md';
    final repo = ref.read(notesRepositoryProvider);
    try {
      final noteId = await repo.createNote(notePath, '');
      if (noteId != null && mounted) {
        context.go('/notes/note/$noteId');
      }
    } catch (e) {
      debugPrint('[MobileBottomInputBar] Error creating note: $e');
    }
  }

  void _onTextChanged() {
    final hasText = _textController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }
}
