import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/spacenotes_theme.dart';
import '../../providers/connection_providers.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../notes_search_bar.dart';

class DesktopChatInput extends ConsumerStatefulWidget {
  const DesktopChatInput({super.key});

  @override
  ConsumerState<DesktopChatInput> createState() => _DesktopChatInputState();
}

class _DesktopChatInputState extends ConsumerState<DesktopChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSend() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    context.read<ChatBloc>().add(SendChatMessage(message));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isOpenCodeConnected =
        ref.watch(openCodeConnectionProvider).valueOrNull ?? false;

    if (!isOpenCodeConnected) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isWorking = chatState is ChatSendingMessage ||
            (chatState is ChatReady && chatState.isStreaming);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                SpaceNotesTheme.background,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: SpaceNotesTheme.inputSurface,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: NotesSearchBar(
                        controller: _controller,
                        height: 48,
                        hintText: 'Ask AI...',
                        onChanged: (_) {},
                        onSubmitted: _onSend,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: SpaceNotesTheme.inputSurface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: isWorking
                          ? () => context.read<ChatBloc>().add(CancelCurrentOperation())
                          : _onSend,
                      tooltip: isWorking ? 'Cancel' : 'Send to AI',
                      icon: Icon(
                        isWorking ? Icons.stop : Icons.arrow_upward,
                        size: 24,
                        color: SpaceNotesTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
