import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/chat_message_list.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/chat/chat_event.dart';
import '../models/space_message.dart';
import '../widgets/terminal_message.dart';
import 'package:go_router/go_router.dart';

class ChatView extends ConsumerStatefulWidget {
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
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _messageListKey = GlobalKey<ChatMessageListState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageListKey.currentState?.scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final showDefaultInput = widget.showInput && isDesktop && widget.customInput == null;

    return BlocListener<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatReady && state.isSending) {
          FocusManager.instance.primaryFocus?.unfocus();
          _messageListKey.currentState?.forceScrollToBottom();
        } else if (state is ChatReady) {
          _messageListKey.currentState?.onMessagesChanged(state.allMessages.length);
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              if (widget.showConnectionStatus) const ConnectionStatusRow(),
              Expanded(child: _buildChatMessagesArea()),
            ],
          ),
          if (showDefaultInput)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DesktopChatInput(),
            ),
          if (widget.customInput != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: widget.customInput!,
            ),
        ],
      ),
    );
  }

  Widget _buildChatMessagesArea() {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state is ChatInitial) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: SpaceNotesTheme.primary),
                SizedBox(height: 16),
                Text('Starting session...', style: SpaceNotesTextStyles.terminal),
              ],
            ),
          );
        }

        if (state is ChatError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: SpaceNotesTheme.error, size: 48),
                const SizedBox(height: 16),
                Text(state.error, style: SpaceNotesTextStyles.terminal, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final messages = state is ChatReady ? state.allMessages : <SpaceMessage>[];
        final targetSession = state is ChatReady ? state.targetSession : 'note-assistant';

        return ChatMessageList(
          key: _messageListKey,
          messages: messages,
          padding: widget.messagePadding ?? const EdgeInsets.fromLTRB(4, 8, 4, 120),
          emptyText: 'Ask me anything...',
          scrollController: widget.scrollController,
          itemBuilder: (message, index) {
            final session = message.session;
            final isOtherSession = session != null && session.isNotEmpty && session != 'note-assistant';

            if (isOtherSession && message.role == 'assistant') {
              return TerminalMessage(
                message: message,
                isPreview: true,
                onTap: () => context.push('/notes/sessions/${Uri.encodeComponent(session)}'),
              );
            }

            return TerminalMessage(
              message: message,
              isTargeted: session != null && session == targetSession && targetSession != 'note-assistant',
              onTap: (session != null && session.isNotEmpty && message.role == 'assistant')
                  ? () => context.read<ChatBloc>().add(SetTargetSession(
                      session == targetSession ? 'note-assistant' : session,
                    ))
                  : null,
            );
          },
        );
      },
    );
  }
}
