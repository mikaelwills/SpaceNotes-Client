import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/terminal_message.dart';

class ChatView extends ConsumerWidget {
  final bool showConnectionStatus;
  final bool showInput;
  final Widget? customInput;
  final EdgeInsets? messagePadding;
  final ScrollController? scrollController;

  const ChatView({
    super.key,
    this.showConnectionStatus = true,
    this.showInput = true,
    this.customInput,
    this.messagePadding,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final showDefaultInput = showInput && isDesktop && customInput == null;
    final targetSession = ref.watch(targetSessionProvider);
    final items = ref.watch(chatTimelineBySessionProvider(targetSession));

    return Stack(
      children: [
        Column(
          children: [
            if (showConnectionStatus) const ConnectionStatusRow(),
            Expanded(
              child: ChatMessageList<ChatItem>(
                items: items,
                itemBuilder: chatItemToWidget,
                keyBuilder: chatItemKey,
                padding:
                    messagePadding ?? const EdgeInsets.fromLTRB(4, 8, 4, 80),
                emptyText: 'Ask me anything...',
                scrollController: scrollController,
              ),
            ),
          ],
        ),
        if (showDefaultInput)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DesktopChatInput(),
          ),
        if (customInput != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: customInput!,
          ),
      ],
    );
  }
}
