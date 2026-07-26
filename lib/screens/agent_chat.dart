import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/terminal_message.dart';

class AgentChatScreen extends ConsumerWidget {
  final String agentId;

  const AgentChatScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref
        .watch(agentHydratedProvider(agentId))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final connected = ref
        .watch(spacetimeConnectionLiveProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    final items = ref.watch(chatTimelineByAgentProvider(agentId));
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return Column(
      children: [
        ConnectionStatusRow(agentId: agentId),
        Expanded(
          child: Stack(
            children: [
              ChatMessageList<ChatItem>(
                items: items,
                itemBuilder: (context, item) => chatItemToWidget(context, item,
                    latestToolId: latestToolIdOf(items)),
                keyBuilder: chatItemKey,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 140),
                hydrating: connected && !hydrated && items.isEmpty,
                maxWidth: double.infinity,
              ),
              if (isDesktop)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DesktopChatInput(agentId: agentId),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
