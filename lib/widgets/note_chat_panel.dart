import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacenotes_theme.dart';
import '../screens/chat_view.dart';
import 'connection_status_row.dart';
import 'desktop/desktop_shell.dart';
import 'note_chat_input.dart';

class NoteChatPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Row(
              children: [
                if (isDesktop)
                  GestureDetector(
                    key: const ValueKey('chat-panel-collapse'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref
                        .read(chatPanelCollapsedProvider.notifier)
                        .state = true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '›',
                        style: TextStyle(
                          fontFamily: SpaceNotesTheme.fontMono,
                          fontSize: 14,
                          color: SpaceNotesTheme.dim,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                const Expanded(child: ConnectionStatusRow()),
              ],
            ),
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
