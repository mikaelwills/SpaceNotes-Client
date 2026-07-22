import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import 'primitives/primitives.dart';

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
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return SnChatDock(
      controller: _controller,
      focusNode: _focusNode,
      hint: _hint,
      onSend: _sendMessage,
      fieldMinHeight: 32,
      fieldPadV: 15,
      sendTileSize: 40,
      padding: EdgeInsets.fromLTRB(14, 8, 14, 15 + keyboardHeight),
    );
  }

  String get _hint {
    if (widget.notePath.isEmpty) return 'ask workflow-agent…';
    final name = widget.notePath.split('/').last.replaceAll('.md', '');
    final trimmed = name.length > 24 ? '${name.substring(0, 24)}…' : name;
    return 'ask about $trimmed…';
  }

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final targetSession = ref.read(targetSessionProvider);
    final text = widget.notePath.isEmpty
        ? message
        : '[Viewing note: ${widget.notePath}]\n\n$message';
    sendChatMessage(
      ref,
      sessionId: targetSession,
      text: text,
    );
    _controller.clear();
    _focusNode.requestFocus();
  }
}
