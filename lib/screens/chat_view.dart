import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/desktop/desktop_chat_input.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/terminal_message.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';

/// ChatView displays the AI chat interface
/// Can be reused in different contexts (main chat, note chat panel)
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
  ScrollController? _ownScrollController;
  bool _showScrollToBottom = false;

  ScrollController get _chatScrollController =>
      widget.scrollController ?? (_ownScrollController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _ownScrollController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final showDefaultInput = widget.showInput && isDesktop && widget.customInput == null;

    return BlocListener<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatReady && state.isSending) {
          _scrollToBottom();
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

        if (state is ChatConnecting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: SpaceNotesTheme.primary),
                SizedBox(height: 16),
                Text('Connecting...', style: SpaceNotesTextStyles.terminal),
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
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.read<SessionBloc>().add(LoadStoredSession());
                  },
                  child: const Text('Retry', style: TextStyle(color: SpaceNotesTheme.primary)),
                ),
              ],
            ),
          );
        }

        final messages = state is ChatReady
            ? state.messages
            : state is ChatPermissionRequired
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
            Listener(
              onPointerMove: (event) {
                if (event.delta.dy > 3) {
                  FocusManager.instance.primaryFocus?.unfocus();
                }
              },
              child: NotificationListener<ScrollNotification>(
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
                child: Center(
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ListView.builder(
                      controller: _chatScrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: widget.messagePadding ?? const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                ),
              ),
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
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
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
            ),
          ),
        ),
      ),
    );
  }
}
