import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/spacenotes_theme.dart';
import '../../providers/chat_providers.dart';
import '../primitives/primitives.dart';

class DesktopChatInput extends ConsumerStatefulWidget {
  final String? sessionId;

  const DesktopChatInput({super.key, this.sessionId});

  @override
  ConsumerState<DesktopChatInput> createState() => _DesktopChatInputState();
}

class _DesktopChatInputState extends ConsumerState<DesktopChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _pendingImageBase64;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SnChatDock(
          controller: _controller,
          focusNode: _focusNode,
          hint: 'ask ai…',
          onSend: _onSend,
          maxLines: 8,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          fieldTrailing: _pendingImageBase64 != null
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
          trailing: [
            SnDockTile(
              icon: Icons.image_outlined,
              onTap: _onPickImage,
              semanticLabel: 'attach image',
            ),
          ],
        ),
      ),
    );
  }

  void _onSend() {
    final message = _controller.text.trim();
    if (message.isEmpty && _pendingImageBase64 == null) return;

    final text = message.isEmpty ? 'What is in this image?' : message;
    final String session =
        widget.sessionId ?? ref.read(targetSessionProvider);
    sendChatMessage(ref, sessionId: session, text: text);
    _controller.clear();
    setState(() => _pendingImageBase64 = null);
  }

  Future<void> _onPickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      setState(() => _pendingImageBase64 = base64);
    } catch (e, stack) {
      debugPrint('[DesktopChatInput] Error picking image: $e');
      debugPrint('[DesktopChatInput] Stack: $stack');
    }
  }
}
