import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
import '../services/debug_logger.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/terminal_message.dart';

class AgentChatScreen extends ConsumerStatefulWidget {
  final String agentId;

  const AgentChatScreen({super.key, required this.agentId});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final Stopwatch _sinceOpen = Stopwatch()..start();
  bool _loggedFirstItems = false;
  bool _loggedSpinner = false;

  @override
  void initState() {
    super.initState();
    debugLogger.chat('agent screen open', 'agent=${widget.agentId}');
  }

  void _traceFirstPaint({
    required int itemCount,
    required bool showingSpinner,
  }) {
    if (showingSpinner && !_loggedSpinner) {
      _loggedSpinner = true;
      debugLogger.chatError(
        'agent screen SPINNER',
        'agent=${widget.agentId} +${_sinceOpen.elapsedMilliseconds}ms — '
            'timeline empty while connected and not yet hydrated, so the '
            'offline cache did not populate this agent before first paint',
      );
    }
    if (itemCount > 0 && !_loggedFirstItems) {
      _loggedFirstItems = true;
      debugLogger.chat(
        'agent screen first items',
        'agent=${widget.agentId} items=$itemCount '
            '+${_sinceOpen.elapsedMilliseconds}ms '
            'sawSpinner=$_loggedSpinner',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentId = widget.agentId;
    final hydrated = ref
        .watch(agentHydratedProvider(agentId))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final connected = ref
        .watch(spacetimeConnectionLiveProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    final items = ref.watch(chatTimelineByAgentProvider(agentId));
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final showingSpinner = connected && !hydrated && items.isEmpty;
    _traceFirstPaint(itemCount: items.length, showingSpinner: showingSpinner);

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
                hydrating: showingSpinner,
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
