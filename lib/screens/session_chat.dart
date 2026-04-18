import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/terminal_message.dart';
import '../widgets/tool_status_row.dart';

class SessionChatScreen extends ConsumerWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(sessionActivityProvider(sessionId));
    final items = ref.watch(chatTimelineBySessionProvider(sessionId));

    return Column(
      children: [
        _buildHeader(sessionId, activity),
        Expanded(
          child: ChatMessageList(
            items: items.map(_itemToWidget).toList(),
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
            maxWidth: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String sessionId, activity) {
    final isActive = activity != null && activity.state != 'idle';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionId,
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ToolStatusRow(activity: activity),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? SpaceNotesTheme.primary
                  : SpaceNotesTheme.secondary,
            ),
          ),
        ],
      ),
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
