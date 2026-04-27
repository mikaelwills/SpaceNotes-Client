import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import '../screens/chat_view.dart';
import 'connection_status_row.dart';
import 'note_chat_input.dart';

class NoteChatPanel extends StatelessWidget {
  final String notePath;
  final VoidCallback? onClose;
  final bool isDesktop;

  const NoteChatPanel({
    super.key,
    required this.notePath,
    required this.isDesktop,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          left: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: isDesktop ? 40 : null,
            child: const ConnectionStatusRow(),
          ),
          Expanded(
            child: ChatView(
              showConnectionStatus: false,
              showInput: false,
              customInput: NoteChatInput(notePath: notePath),
              messagePadding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            ),
          ),
        ],
      ),
    );
  }
}
