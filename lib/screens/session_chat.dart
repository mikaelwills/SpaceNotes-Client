import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
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
    final hydrated = ref
        .watch(sessionHydratedProvider(sessionId))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final connected = ref
        .watch(spacetimeConnectionLiveProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    final items = ref.watch(chatTimelineBySessionProvider(sessionId));
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return Column(
      children: [
        ConnectionStatusRow(sessionId: sessionId),
        Expanded(
          child: Stack(
            children: [
              ChatMessageList<ChatItem>(
                items: items,
                itemBuilder: chatItemToWidget,
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
                  child: DesktopChatInput(sessionId: sessionId),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
