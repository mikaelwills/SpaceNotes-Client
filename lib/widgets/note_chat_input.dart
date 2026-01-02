import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';
import '../blocs/session/session_state.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import 'notes_search_bar.dart';

class NoteChatInput extends StatefulWidget {
  final String notePath;
  final VoidCallback? onClose;
  final bool isDesktop;

  const NoteChatInput({
    super.key,
    required this.notePath,
    this.onClose,
    this.isDesktop = false,
  });

  @override
  State<NoteChatInput> createState() => _NoteChatInputState();
}

class _NoteChatInputState extends State<NoteChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _sessionCreated = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _noteName {
    final name = widget.notePath.split('/').last.replaceAll('.md', '');
    return name.length > 20 ? '${name.substring(0, 20)}...' : name;
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final sessionBloc = context.read<SessionBloc>();
    final chatBloc = context.read<ChatBloc>();

    if (!_sessionCreated) {
      sessionBloc.add(const CreateSession());
      _sessionCreated = true;

      await sessionBloc.stream.firstWhere((state) => state is SessionLoaded);
      await chatBloc.stream.firstWhere((state) => state is ChatReady);
    }

    final prefixedMessage = '[Viewing note: ${widget.notePath}]\n\n$message';
    chatBloc.add(SendChatMessage(prefixedMessage));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.isDesktop ? 36.0 : 48.0;
    final iconSize = widget.isDesktop ? 20.0 : 24.0;
    final inputHeight = widget.isDesktop ? 36.0 : 48.0;
    final borderRadius = widget.isDesktop ? 18.0 : 28.0;

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isWorking = chatState is ChatReady && chatState.isWorking;

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
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: SpaceNotesTheme.inputSurface,
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: NotesSearchBar(
                      controller: _controller,
                      height: inputHeight,
                      hintText: 'Ask about $_noteName...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: const BoxDecoration(
                    color: SpaceNotesTheme.inputSurface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isWorking
                        ? () => context.read<ChatBloc>().add(CancelCurrentOperation())
                        : _sendMessage,
                    tooltip: isWorking ? 'Cancel' : 'Send to AI',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isWorking ? Icons.stop : Icons.arrow_upward,
                      size: iconSize,
                      color: SpaceNotesTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
