import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
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
  Uint8List? _pendingImageBytes;

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
          fieldTrailing: _pendingImageBytes != null
              ? GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _pendingImageBytes = null);
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
    final image = _pendingImageBytes;
    if (message.isEmpty && image == null) return;

    final String session = widget.sessionId ?? ref.read(targetSessionProvider);
    if (image != null) {
      sendChatImage(ref, sessionId: session, caption: message, pngBytes: image);
    } else {
      sendChatMessage(ref, sessionId: session, text: message);
    }
    _controller.clear();
    setState(() => _pendingImageBytes = null);
  }

  Future<void> _onPickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final raw = await image.readAsBytes();
      final png = await compute(_resizeToPng, raw);
      if (png == null) {
        debugPrint('[DesktopChatInput] Image decode failed');
        return;
      }
      if (png.length > 2 * 1024 * 1024) {
        debugPrint(
            '[DesktopChatInput] Image exceeds 2MB post-compress: ${png.length}');
        return;
      }

      setState(() => _pendingImageBytes = png);
    } catch (e, stack) {
      debugPrint('[DesktopChatInput] Error picking image: $e');
      debugPrint('[DesktopChatInput] Stack: $stack');
    }
  }
}

Uint8List? _resizeToPng(Uint8List bytes) {
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
