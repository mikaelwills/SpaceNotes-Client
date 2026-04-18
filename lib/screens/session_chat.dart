import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/terminal_message.dart';

class SessionChatScreen extends ConsumerWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(chatTimelineBySessionProvider(sessionId));
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return Column(
      children: [
        ConnectionStatusRow(sessionId: sessionId),
        Expanded(
          child: Stack(
            children: [
              ChatMessageList(
                items: items.map(_itemToWidget).toList(),
                padding: EdgeInsets.fromLTRB(4, 8, 4, isDesktop ? 140 : 140),
                maxWidth: double.infinity,
              ),
              if (isDesktop)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DesktopChatInput(sessionId: sessionId),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemToWidget(ChatItem item) {
    return switch (item) {
      ChatMessageItem(:final message) => TerminalMessage(message: message),
      ChatToolItem(:final event) => ToolEventRow(event: event),
      ChatPermissionItem(:final request) => PermissionRow(request: request),
    };
  }
}
