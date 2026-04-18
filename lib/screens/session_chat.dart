import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/terminal_message.dart';

class SessionChatScreen extends ConsumerWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(chatTimelineBySessionProvider(sessionId));

    return Column(
      children: [
        ConnectionStatusRow(sessionId: sessionId),
        Expanded(
          child: ChatMessageList(
            items: items.map(_itemToWidget).toList(),
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 140),
            maxWidth: double.infinity,
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
