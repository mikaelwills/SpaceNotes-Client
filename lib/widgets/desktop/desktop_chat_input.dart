import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chat_providers.dart';
import '../../services/chat_attachments.dart';
import '../../services/debug_logger.dart';
import '../../services/paste_image_listener.dart';
import '../../theme/spacenotes_theme.dart';
import '../chat_pending_images.dart';
import '../primitives/primitives.dart';

class DesktopChatInput extends ConsumerStatefulWidget {
  final String? agentId;

  const DesktopChatInput({super.key, this.agentId});

  @override
  ConsumerState<DesktopChatInput> createState() => _DesktopChatInputState();
}

class _DesktopChatInputState extends ConsumerState<DesktopChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final PasteImageListener _pasteListener = createPasteImageListener();
  final ImagePicker _imagePicker = ImagePicker();
  List<PendingChatImage> _pendingImages = const [];
  bool _sendingImages = false;

  @override
  void initState() {
    super.initState();
    _pasteListener.register(_onPastedImageBytes);
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
    _pasteListener.unregister();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _full => _pendingImages.length >= maxPendingChatImages;

  @override
  Widget build(BuildContext context) {
    final String agent = widget.agentId ?? ref.watch(targetAgentProvider);
    final agentState = ref.watch(agentActivityProvider(agent))?.state;
    final agentBusy = agentState == 'thinking' || agentState == 'tool_use';
    final canAdd = !_full && !_sendingImages;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SnChatDock(
          controller: _controller,
          focusNode: _focusNode,
          hint: 'ask ai…',
          onSend: _onSend,
          maxLines: 6,
          showFade: false,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          header: ChatPendingImages(
            images: _pendingImages,
            sending: _sendingImages,
            onRemove: (index) => setState(() {
              _pendingImages = [..._pendingImages]..removeAt(index);
            }),
          ),
          leading: [
            SnDockTile(
              key: const ValueKey('chat_add_image'),
              icon: Icons.add,
              onTap: canAdd ? _onPickImage : () {},
              color: canAdd ? SpaceNotesTheme.accent : SpaceNotesTheme.dim,
              semanticLabel: 'add image',
            ),
          ],
          trailing: [
            if (agentState == 'tool_use')
              SnDockTile(
                key: const ValueKey('chat_background_button'),
                icon: Icons.flip_to_back,
                onTap: () => sendChatBackground(ref, agentId: agent),
                semanticLabel: 'background',
              ),
            if (agentBusy)
              SnDockTile(
                key: const ValueKey('chat_stop_button'),
                icon: Icons.stop,
                color: SpaceNotesTheme.offline,
                onTap: () => sendChatStop(ref, agentId: agent),
                semanticLabel: 'stop',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPastedImageBytes(Uint8List raw) async {
    if (_full || _sendingImages) return;
    final image = await compute(normalizeChatImage, (raw, 'pasted.png'));
    if (!mounted) return;
    if (image == null) {
      _showError('Pasted image could not be read');
      return;
    }
    setState(() => _pendingImages = [..._pendingImages, image]);
  }

  void _onSend() {
    if (_sendingImages) return;
    final message = _controller.text.trim();
    final images = _pendingImages;
    if (message.isEmpty && images.isEmpty) return;

    final String agent = widget.agentId ?? ref.read(targetAgentProvider);
    _controller.clear();
    if (images.isEmpty) {
      sendChatMessage(ref, agentId: agent, text: message);
      return;
    }
    _sendImages(agentId: agent, caption: message, images: images);
  }

  Future<void> _sendImages({
    required String agentId,
    required String caption,
    required List<PendingChatImage> images,
  }) async {
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
      if (mounted && _controller.text.isEmpty) _controller.text = caption;
      _showError('Images not sent: $e');
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
      HapticFeedback.lightImpact();
      setState(() => _pendingImages = [..._pendingImages, ...picked]);
    } catch (e, st) {
      debugLogger.error('CHAT_IMAGES', 'Pick failed', '$e\n$st');
      _showError('Could not add images: $e');
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
