import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/spacenotes_theme.dart';
import '../../providers/connection_providers.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../notes_search_bar.dart';

class DesktopChatInput extends ConsumerStatefulWidget {
  const DesktopChatInput({super.key});

  @override
  ConsumerState<DesktopChatInput> createState() => _DesktopChatInputState();
}

class _DesktopChatInputState extends ConsumerState<DesktopChatInput> {
  final TextEditingController _controller = TextEditingController();
  String? _pendingImageBase64;
  String? _pendingImageMimeType;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSend() {
    final message = _controller.text.trim();
    if (message.isEmpty && _pendingImageBase64 == null) return;

    context.read<ChatBloc>().add(SendChatMessage(
      message.isEmpty ? 'What is in this image?' : message,
      imageBase64: _pendingImageBase64,
      imageMimeType: _pendingImageMimeType,
    ));
    _controller.clear();
    setState(() {
      _pendingImageBase64 = null;
      _pendingImageMimeType = null;
    });
  }

  Future<void> _onPickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      debugPrint('[DesktopChatInput] Image selected: ${image.path}, name: ${image.name}');

      final bytes = await image.readAsBytes();
      debugPrint('[DesktopChatInput] Read ${bytes.length} bytes');

      final base64 = base64Encode(bytes);
      debugPrint('[DesktopChatInput] Base64 length: ${base64.length}');

      final extension = image.name.split('.').last.toLowerCase();
      debugPrint('[DesktopChatInput] Extension: $extension');

      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      debugPrint('[DesktopChatInput] MimeType: $mimeType');

      setState(() {
        _pendingImageBase64 = base64;
        _pendingImageMimeType = mimeType;
      });
    } catch (e, stack) {
      debugPrint('[DesktopChatInput] Error picking image: $e');
      debugPrint('[DesktopChatInput] Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpenCodeConnected =
        ref.watch(openCodeConnectionProvider).valueOrNull ?? false;

    if (!isOpenCodeConnected) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isWorking = chatState is ChatSendingMessage ||
            (chatState is ChatReady && chatState.isStreaming);

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
                            _pendingImageMimeType = null;
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
                      onPressed: isWorking
                          ? () => context.read<ChatBloc>().add(CancelCurrentOperation())
                          : _onSend,
                      tooltip: isWorking ? 'Cancel' : 'Send to AI',
                      icon: Icon(
                        isWorking ? Icons.stop : Icons.arrow_upward,
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
      },
    );
  }
}
