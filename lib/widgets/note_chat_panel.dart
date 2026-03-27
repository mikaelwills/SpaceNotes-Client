import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import '../screens/chat_view.dart';
import 'note_chat_input.dart';

class NoteChatPanel extends StatelessWidget {
  final String notePath;
  final VoidCallback onClose;
  final bool isDesktop;

  const NoteChatPanel({
    super.key,
    required this.notePath,
    required this.onClose,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.background,
        border: Border(
          left: BorderSide(
            color: SpaceNotesTheme.inputSurface,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ChatView(
              showConnectionStatus: false,
              showInput: false,
              customInput: NoteChatInput(
                notePath: notePath,
                onClose: onClose,
              ),
              messagePadding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final noteName = notePath.split('/').last.replaceAll('.md', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: SpaceNotesTheme.inputSurface,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: SpaceNotesTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chat: $noteName',
              style: SpaceNotesTextStyles.terminal.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              size: 20,
              color: SpaceNotesTheme.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }
}
