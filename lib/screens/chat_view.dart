import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/terminal_message.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';

/// ChatView displays the AI chat interface
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _chatScrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void dispose() {
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ConnectionStatusRow(),
        Expanded(child: _buildChatMessagesArea()),
      ],
    );
  }

  Widget _buildChatMessagesArea() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatReady || state is ChatSendingMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_chatScrollController.hasClients) {
              _chatScrollController.animateTo(
                _chatScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      builder: (context, state) {
        final messages = state is ChatReady
            ? state.messages
            : state is ChatSendingMessage
                ? state.messages
                : <dynamic>[];
        final isStreaming = state is ChatReady ? state.isStreaming : false;

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Ask me anything...',
              style: SpaceNotesTextStyles.terminal,
            ),
          );
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final isNearBottom = _chatScrollController.position.pixels >=
                      _chatScrollController.position.maxScrollExtent - 100;
                  if (_showScrollToBottom == isNearBottom) {
                    setState(() => _showScrollToBottom = !isNearBottom);
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isLastMessage = index == messages.length - 1;
                  final isStreamingMessage = isStreaming && isLastMessage;

                  return TerminalMessage(
                    message: message,
                    isStreaming: isStreamingMessage,
                  );
                },
              ),
            ),
            if (_showScrollToBottom) _buildScrollToBottomButton(),
          ],
        );
      },
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: SpaceNotesTheme.inputSurface,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          },
          tooltip: 'Scroll to bottom',
          icon: const Icon(
            Icons.arrow_downward,
            size: 24,
            color: SpaceNotesTheme.primary,
          ),
        ),
      ),
    );
  }
}
