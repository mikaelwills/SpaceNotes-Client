import 'dart:io';
import 'package:flutter/material.dart';
import '../platform/capabilities.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/audio_playback_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../providers/upload_progress_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../screens/credential_screen.dart';
import '../screens/home_screen.dart';
import 'primitives/primitives.dart';
import 'audio_mini_bar.dart';
import 'folder_picker_field.dart';
import '../file_types/file_type_registry.dart';
import '../services/chat_attachments.dart';
import '../services/debug_logger.dart';
import 'chat_pending_images.dart';
import '../services/folder_upload.dart';
import '../services/file_transfer_service.dart';
import '../theme/spacenotes_theme.dart';
import 'adaptive/platform_utils.dart';

class MobileBottomInputBar extends ConsumerStatefulWidget {
  const MobileBottomInputBar({super.key});

  @override
  ConsumerState<MobileBottomInputBar> createState() =>
      _MobileBottomInputBarState();
}

class _MobileBottomInputBarState extends ConsumerState<MobileBottomInputBar> {
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _focusNode = ref.read(mobileInputFocusNodeProvider);
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasText = false;
  bool _isFocused = false;
  List<PendingChatImage> _pendingImages = const [];
  bool _sendingImages = false;
  HomeViewType? _focusedForView;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    PendingChatImageSink.add = _addPendingImages;
  }

  void _addPendingImages(List<PendingChatImage> images) {
    if (!mounted) return;
    final room = maxPendingChatImages - _pendingImages.length;
    setState(() => _pendingImages = [..._pendingImages, ...images.take(room)]);
  }

  @override
  void dispose() {
    if (PendingChatImageSink.add == _addPendingImages) {
      PendingChatImageSink.add = null;
    }
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _getCurrentViewType();

    if (PlatformUtils.isDesktopPlatform &&
        _isFocusableView(viewType) &&
        _focusedForView != viewType) {
      _focusedForView = viewType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!_isFocusableView(viewType)) {
      _focusedForView = null;
    }

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

    final searchQuery = viewType == HomeViewType.passwords
        ? ref.watch(credentialFilterProvider)
        : ref.watch(folderSearchQueryProvider);
    final queryClearedElsewhere =
        !isChat && searchQuery.isEmpty && _textController.text.isNotEmpty;
    if (queryClearedElsewhere && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) _textController.clear();
      });
    }

    final folderPath = ref.watch(currentFolderPathProvider);
    final audioFileId =
        ref.watch(audioPlaybackProvider.select((s) => s.fileId));
    final attachedToMiniBar = AudioMiniBar.isVisible(context, audioFileId);

    final chatAgentId =
        isChat ? (_getCurrentAgentId() ?? ref.watch(targetAgentProvider)) : null;
    final agentState = chatAgentId == null
        ? null
        : ref.watch(agentActivityProvider(chatAgentId))?.state;
    final showStop = !_isFocused &&
        (agentState == 'thinking' || agentState == 'tool_use');

    return SafeArea(
      top: false,
      child: _buildDock(
        viewType: viewType,
        isChat: isChat,
        isAgentChat: isAgentChat,
        folderPath: folderPath,
        attachedToMiniBar: attachedToMiniBar,
        chatAgentId: chatAgentId,
        showStop: showStop,
        toolRunning: chatAgentId != null &&
            ref.watch(agentLongToolProvider(chatAgentId)),
      ),
    );
  }

  Widget _buildDock({
    required HomeViewType viewType,
    required bool isChat,
    required bool isAgentChat,
    required String folderPath,
    required bool attachedToMiniBar,
    required String? chatAgentId,
    required bool showStop,
    required bool toolRunning,
  }) {
    return SnChatDock(
        controller: _textController,
        focusNode: _focusNode,
        hint: _computeHint(isChat),
        padding: attachedToMiniBar
            ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
            : const EdgeInsets.fromLTRB(12, 8, 12, 12),
        borderRadius: attachedToMiniBar
            ? const BorderRadius.vertical(
                bottom: Radius.circular(SpaceNotesTheme.radiusXs))
            : const BorderRadius.all(Radius.circular(SpaceNotesTheme.radiusXs)),
        onChanged: isChat ? null : _onSearchChanged,
        onSend: _onSend,
        showSend: viewType != HomeViewType.passwords &&
            (isChat || _isFocused || _hasText) &&
            !showStop,
        header: isChat
            ? ChatPendingImages(
                images: _pendingImages,
                sending: _sendingImages,
                onRemove: (index) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _pendingImages = [..._pendingImages]..removeAt(index);
                  });
                },
              )
            : null,
        leading: [
          if (isAgentChat)
            SnDockTile(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
              semanticLabel: 'back',
              width: 44,
            ),
          if (isChat) _addImageTile(),
        ],
        trailing: [
          ..._buildTrailing(isChat, folderPath),
          if (showStop && toolRunning && chatAgentId != null)
            SnDockTile(
              key: const ValueKey('chat_background_button'),
              icon: Icons.flip_to_back,
              onTap: () {
                HapticFeedback.mediumImpact();
                sendChatBackground(ref, agentId: chatAgentId);
              },
              semanticLabel: 'background',
            ),
          if (showStop && chatAgentId != null)
            SnDockTile(
              key: const ValueKey('chat_stop_button'),
              icon: Icons.stop,
              color: SpaceNotesTheme.offline,
              onTap: () {
                HapticFeedback.mediumImpact();
                sendChatStop(ref, agentId: chatAgentId);
              },
              semanticLabel: 'stop',
            ),
        ],
    );
  }

  Widget _addImageTile() {
    final disabled =
        _pendingImages.length >= maxPendingChatImages || _sendingImages;
    return SnDockTile(
      key: const ValueKey('chat_add_image'),
      icon: Icons.add,
      onTap: disabled ? () {} : _onPickImage,
      color: disabled ? SpaceNotesTheme.dim : SpaceNotesTheme.accent,
      semanticLabel: 'add image',
      width: 36,
    );
  }

  String _computeHint(bool isChat) {
    if (_getCurrentViewType() == HomeViewType.passwords) {
      return 'search passwords…';
    }
    if (!isChat) return 'search notes…';
    final aid = _getCurrentAgentId();
    if (aid != null) return aid;
    return ref.read(targetAgentProvider);
  }

  List<Widget> _buildTrailing(bool isChat, String folderPath) {
    if (isChat) return const [];
    if (_getCurrentViewType() == HomeViewType.passwords) {
      return [
        SnDockTile(
          icon: Icons.add,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CredentialCreateScreen()),
          ),
          semanticLabel: 'new credential',
        ),
      ];
    }
    if (_isFocused || _hasText) {
      return const [];
    }
    return [
      SnDockTile(
        key: const ValueKey('action-new-folder'),
        icon: Icons.create_new_folder_outlined,
        onTap: () => NotesListDialogs.showCreateFolderDialog(
          context,
          ref,
          currentPath: folderPath,
        ),
        semanticLabel: 'new folder',
      ),
      if (Capabilities.canUploadFiles)
        SnDockTile(
          key: const ValueKey('action-upload'),
          icon: Icons.cloud_upload_outlined,
          onTap: () => _uploadFiles(folderPath),
          semanticLabel: 'upload files',
        ),
      SnDockTile(
        key: const ValueKey('action-new-note'),
        icon: Icons.post_add_outlined,
        onTap: () => _createQuickNote(folderPath),
        semanticLabel: 'new note',
      ),
    ];
  }

  HomeViewType _getCurrentViewType() {
    final l = GoRouterState.of(context).uri.toString();
    if (l.startsWith('/agents/chat')) return HomeViewType.chat;
    if (l.startsWith('/notes/note/')) return HomeViewType.note;
    if (l.startsWith('/notes/passwords')) return HomeViewType.passwords;
    if (l == '/agents') return HomeViewType.agents;
    if (l.startsWith('/agents/')) return HomeViewType.agentChat;
    return HomeViewType.folders;
  }

  String? _getCurrentAgentId() {
    final l = GoRouterState.of(context).uri.toString();
    if (l.startsWith('/agents/chat')) return null;
    if (!l.startsWith('/agents/')) return null;
    final encoded = l.substring('/agents/'.length);
    return Uri.decodeComponent(encoded);
  }

  bool _isFocusableView(HomeViewType v) =>
      v != HomeViewType.note && v != HomeViewType.agents;

  void _onSearchChanged(String query) {
    if (_getCurrentViewType() == HomeViewType.passwords) {
      ref.read(credentialFilterProvider.notifier).state = query;
      return;
    }
    ref.read(folderSearchQueryProvider.notifier).state = query;
  }

  void _onSend() {
    if (_sendingImages) return;
    final message = _textController.text.trim();
    final images = _pendingImages;
    if (message.isEmpty && images.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final routeAgent = _getCurrentAgentId();
    final String agentId = routeAgent ?? ref.read(targetAgentProvider);
    _textController.clear();

    if (images.isEmpty) {
      sendChatMessage(ref, agentId: agentId, text: message);
    } else {
      _sendImages(agentId: agentId, caption: message, images: images);
    }

    if (routeAgent == null) {
      context.go('/agents/chat');
      ref.read(folderSearchQueryProvider.notifier).state = '';
    }
  }

  Future<void> _sendImages({
    required String agentId,
    required String caption,
    required List<PendingChatImage> images,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _sendingImages = true);
    try {
      await sendChatImages(
        ref,
        agentId: agentId,
        caption: caption,
        images: images,
      );
      if (mounted) setState(() => _pendingImages = const []);
    } catch (e, st) {
      debugLogger.error('CHAT_IMAGES', 'Send failed', '$e\n$st');
      if (mounted && _textController.text.isEmpty) {
        _textController.text = caption;
      }
      messenger?.showSnackBar(
        SnackBar(content: Text('Images not sent: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingImages = false);
    }
  }

  Future<void> _onPickImage() async {
    try {
      final picked = await pickChatImages(
        _imagePicker,
        limit: maxPendingChatImages - _pendingImages.length,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() => _pendingImages = [..._pendingImages, ...picked]);
    } catch (e, st) {
      debugLogger.error('CHAT_IMAGES', 'Pick failed', '$e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Could not add images: $e')),
      );
    }
  }

  Future<void> _uploadFiles(String folderPath) async {
    final prePopulated = folderPath.isEmpty ? 'All Notes' : folderPath;
    final target =
        await pickUploadTarget(context, ref, currentFolder: prePopulated);
    if (target == null || !mounted) return;

    final repo = ref.read(notesRepositoryProvider);
    await repo.createFolder(target.folder);
    final targetFolder = target.folder;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: target.source!,
    );
    if (result == null || result.files.isEmpty) {
      debugLogger.info('UPLOAD', 'File picker cancelled or empty selection');
      return;
    }
    debugLogger.info(
      'UPLOAD',
      'Files selected',
      'count=${result.files.length} folder=$targetFolder',
    );

    final service = ref.read(fileTransferServiceProvider);
    final batch = ref.read(uploadBatchProvider.notifier);
    final uploadable = result.files.where((f) => f.path != null).toList();

    if (uploadable.length == 1) {
      final picked = uploadable.first;
      if (!FileTypeRegistry.isUploadable(picked.name)) {
        if (!mounted) return;
        await showUnsupportedFilesDialog(context, [picked.name]);
        return;
      }
      await _uploadSingleWithCollisionDialog(
        service,
        batch,
        targetFolder,
        picked,
      );
      return;
    }

    final uploadResult = await uploadFilesToFolder(
      service: service,
      batch: batch,
      folderPath: targetFolder,
      files: [for (final picked in uploadable) File(picked.path!)],
    );

    if (!mounted) return;
    await showUploadOutcomeDialogs(context, uploadResult);
  }

  Future<void> _uploadSingleWithCollisionDialog(
    FileTransferService service,
    UploadBatchNotifier batch,
    String targetFolder,
    PlatformFile picked,
  ) async {
    final path = picked.path!;
    final jobId = '${DateTime.now().microsecondsSinceEpoch}_${picked.name}';

    batch.startBatch([(id: jobId, fileName: picked.name)]);
    try {
      await service.uploadFile(
        targetFolder,
        File(path),
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(jobId, sent / total,
                sentBytes: sent, totalBytes: total);
          }
        },
      );
      batch.complete(jobId);
      batch.finishBatch();
    } on FileAlreadyExistsException {
      batch.finishBatch();
      if (!mounted) return;
      await _showAlreadyExistsDialog(picked.name, targetFolder);
    } catch (e) {
      debugLogger.error(
          'UPLOAD', 'Error uploading ${picked.name}', e.toString());
      batch.fail(jobId, e.toString());
      batch.finishBatch();
      if (!mounted) return;
      showUploadFailedDialog(context, [picked.name]);
    }
  }

  Future<void> _showAlreadyExistsDialog(String fileName, String folderName) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => SnDialog(
        title: 'File already exists',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'already exists in $folderName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.muted,
              ),
            ),
          ],
        ),
        actions: [
          SnDialogAction(
            label: 'OK',
            variant: SnButtonVariant.outline,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _createQuickNote(String folderPath) async {
    final basePath = folderPath.isEmpty ? 'All Notes' : folderPath;
    final notePath = '$basePath/${FileTypeRegistry.defaultNewFileName()}';
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
