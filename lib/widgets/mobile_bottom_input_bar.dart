import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../theme/spacenotes_theme.dart';
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
  String? _pendingImageBase64;

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

    if (viewType == HomeViewType.note || viewType == HomeViewType.sessions) {
      return const SizedBox.shrink();
    }
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/settings') {
      return const SizedBox.shrink();
    }

    final isChat =
        viewType == HomeViewType.chat || viewType == HomeViewType.sessionChat;
    final isSessionChat = viewType == HomeViewType.sessionChat;

    final searchQuery = ref.watch(folderSearchQueryProvider);
    if (!isChat && searchQuery.isEmpty && _textController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textController.clear();
      });
    }

    final folderPath = ref.watch(currentFolderPathProvider);

    return Stack(
      children: [
        _buildGradient(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSessionChat) ...[
                  _DockTile(
                    icon: Icons.arrow_back,
                    onTap: () => context.pop(),
                    semanticLabel: 'back',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: _buildField(isChat)),
                const SizedBox(width: 8),
                ..._buildTrailing(isChat, folderPath),
              ],
            ),
          ),
        ),
      ],
    );
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

  Widget _buildGradient() {
    return const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x000D0D0F), Color(0xD90D0D0F)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(bool isChat) {
    final hint = _computeHint(isChat);
    final hasImage = _pendingImageBase64 != null;

    return SnField(
      controller: _textController,
      focusNode: _focusNode,
      hint: hint,
      onChanged: isChat ? (_) {} : _onSearchChanged,
      onSubmitted: (_) => _onSend(),
      maxLines: 6,
      minLines: 1,
      expands: false,
      trailing: hasImage
          ? GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _pendingImageBase64 = null);
              },
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.image,
                size: 16,
                color: SpaceNotesTheme.accent,
              ),
            )
          : null,
    );
  }

  String _computeHint(bool isChat) {
    if (!isChat) return 'search notes…';
    final sid = _getCurrentSessionId();
    if (sid != null) return sid;
    return ref.read(targetSessionProvider);
  }

  List<Widget> _buildTrailing(bool isChat, String folderPath) {
    if (isChat) {
      return [
        _DockTile(
          icon: Icons.image_outlined,
          onTap: _onPickImage,
          semanticLabel: 'attach image',
        ),
        const SizedBox(width: 8),
        _DockTile(
          icon: Icons.arrow_upward,
          onTap: _onSend,
          semanticLabel: 'send',
        ),
      ];
    }
    if (_isFocused || _hasText) {
      return [
        _DockTile(
          icon: Icons.arrow_upward,
          onTap: _onSend,
          semanticLabel: 'send to AI',
        ),
      ];
    }
    return [
      _DockTile(
        icon: Icons.create_new_folder_outlined,
        onTap: () => NotesListDialogs.showCreateFolderDialog(
          context,
          ref,
          currentPath: folderPath,
        ),
        semanticLabel: 'new folder',
      ),
      const SizedBox(width: 8),
      _DockTile(
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

  void _onSend() {
    final message = _textController.text.trim();
    if (message.isEmpty && _pendingImageBase64 == null) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final sessionId = _getCurrentSessionId();
    if (sessionId != null) {
      sendChatMessage(ref, sessionId: sessionId, text: message);
      _textController.clear();
      setState(() => _pendingImageBase64 = null);
      return;
    }

    final targetSession = ref.read(targetSessionProvider);
    final text = message.isEmpty ? 'What is in this image?' : message;
    sendChatMessage(ref, sessionId: targetSession, text: text);
    context.go('/notes/chat');

    _textController.clear();
    ref.read(folderSearchQueryProvider.notifier).state = '';
    setState(() => _pendingImageBase64 = null);
  }

  Future<void> _onPickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      var bytes = await compute(_readFileBytes, image.path);
      if (bytes.length > 4 * 1024 * 1024) {
        bytes = await compute(_compressImage, bytes);
      }

      setState(() => _pendingImageBase64 = base64Encode(bytes));
    } catch (e) {
      debugPrint('[MobileBottomInputBar] Error picking image: $e');
    }
  }

  static Uint8List _compressImage(Uint8List bytes) {
    final img = image_lib.decodeImage(bytes);
    if (img == null) return bytes;

    var resized = img;
    if (img.width > 2048 || img.height > 2048) {
      resized = image_lib.copyResize(img,
          width: img.width > img.height ? 2048 : -1,
          height: img.height >= img.width ? 2048 : -1);
    }

    for (final quality in [90, 80, 70, 60]) {
      final jpeg =
          Uint8List.fromList(image_lib.encodeJpg(resized, quality: quality));
      if (jpeg.length <= 4 * 1024 * 1024) return jpeg;
    }

    return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 50));
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
}

class _DockTile extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _DockTile({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border.all(
              color: SpaceNotesTheme.hairlineStrong,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusDock),
          ),
          child: Icon(icon, size: 16, color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }
}
