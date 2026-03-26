import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../blocs/session_chat/session_chat_bloc.dart';
import '../blocs/session_chat/session_chat_event.dart';
import '../blocs/session_chat/session_chat_state.dart';
import '../services/space_channel_service.dart';
import '../theme/spacenotes_theme.dart';

class SessionChatScreen extends StatefulWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  late final SessionChatBloc _chatBloc;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatBloc = SessionChatBloc(
      GetIt.I<SpaceChannelService>(),
      sessionId: widget.sessionId,
    );
    _chatBloc.add(SessionChatStarted(widget.sessionId));
  }

  @override
  void dispose() {
    _chatBloc.add(const SessionChatStopped());
    _chatBloc.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _getSessionInfo();
    final projectName = info?.project ?? widget.sessionId;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SpaceNotesTheme.primaryMuted, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.terminal_outlined, size: 18, color: SpaceNotesTheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (info?.task.isNotEmpty == true)
                      Text(
                        info!.task,
                        style: const TextStyle(
                          fontFamily: 'FiraCode',
                          fontSize: 11,
                          color: SpaceNotesTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: info != null ? SpaceNotesTheme.secondary : SpaceNotesTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<SessionChatBloc, SessionChatState>(
            bloc: _chatBloc,
            builder: (context, state) {
              if (state.messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(
                      color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];
                  final isUser = msg.role == 'user';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isUser
                              ? SpaceNotesTheme.primary.withValues(alpha: 0.15)
                              : SpaceNotesTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isUser
                                ? SpaceNotesTheme.primary.withValues(alpha: 0.2)
                                : SpaceNotesTheme.primaryMuted,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUser ? SpaceNotesTheme.primary : SpaceNotesTheme.text,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: SpaceNotesTheme.primaryMuted, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 13, color: SpaceNotesTheme.text),
                  decoration: InputDecoration(
                    hintText: 'Message $projectName...',
                    hintStyle: const TextStyle(color: SpaceNotesTheme.textSecondary, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: SpaceNotesTheme.primaryMuted),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, size: 18),
                color: SpaceNotesTheme.primary,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  SessionInfo? _getSessionInfo() {
    final sessionBloc = GetIt.I<SessionBloc>();
    return sessionBloc.state.sessions[widget.sessionId];
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _chatBloc.add(SessionChatSendMessage(text));
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
