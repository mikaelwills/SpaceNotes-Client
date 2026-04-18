import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/spacenotes_theme.dart';
import '../../providers/chat_providers.dart';
import '../notes_search_bar.dart';

class DesktopChatInput extends ConsumerStatefulWidget {
  const DesktopChatInput({super.key});

  @override
  ConsumerState<DesktopChatInput> createState() => _DesktopChatInputState();
}

class _DesktopChatInputState extends ConsumerState<DesktopChatInput> {
  final TextEditingController _controller = TextEditingController();
  String? _pendingImageBase64;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: SpaceNotesTheme.inputSurface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: NotesSearchBar(
                    controller: _controller,
                    height: 48,
                    hintText: 'Ask AI...',
                    onChanged: (_) {},
                    showImagePicker: true,
                    onImagePickerTap: _onPickImage,
                    hasImageAttached: _pendingImageBase64 != null,
                    onClearImage: () {
                      setState(() {
                        _pendingImageBase64 = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: SpaceNotesTheme.inputSurface,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _onSend,
                  tooltip: 'Send to AI',
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 24,
                    color: SpaceNotesTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSend() {
    final message = _controller.text.trim();
    if (message.isEmpty && _pendingImageBase64 == null) return;

    final text = message.isEmpty ? 'What is in this image?' : message;
    final targetSession = ref.read(targetSessionProvider);
    sendChatMessage(ref, sessionId: targetSession, text: text);
    _controller.clear();
    setState(() {
      _pendingImageBase64 = null;
    });
  }

  Future<void> _onPickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      setState(() {
        _pendingImageBase64 = base64;
      });
    } catch (e, stack) {
      debugPrint('[DesktopChatInput] Error picking image: $e');
      debugPrint('[DesktopChatInput] Stack: $stack');
    }
  }
}
