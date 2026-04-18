import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/chat_providers.dart';
import 'notes_search_bar.dart';

class NoteChatInput extends ConsumerStatefulWidget {
  final String notePath;
  final VoidCallback? onClose;

  const NoteChatInput({
    super.key,
    required this.notePath,
    this.onClose,
  });

  @override
  ConsumerState<NoteChatInput> createState() => _NoteChatInputState();
}

class _NoteChatInputState extends ConsumerState<NoteChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

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
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight),
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
                hintText: 'Ask about $_noteName...',
                onChanged: (_) {},
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
              onPressed: _sendMessage,
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
    );
  }

  String get _noteName {
    final name = widget.notePath.split('/').last.replaceAll('.md', '');
    return name.length > 20 ? '${name.substring(0, 20)}...' : name;
  }

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    FocusScope.of(context).unfocus();

    final prefixedMessage = '[Viewing note: ${widget.notePath}]\n\n$message';
    final targetSession = ref.read(targetSessionProvider);
    sendChatMessage(
      ref,
      sessionId: targetSession,
      text: prefixedMessage,
    );
    _controller.clear();
  }
}
