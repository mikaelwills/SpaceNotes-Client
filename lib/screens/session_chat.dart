import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../blocs/session_chat/session_chat_bloc.dart';
import '../blocs/session_chat/session_chat_state.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/terminal_message.dart';

class SessionChatScreen extends StatefulWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionBloc = context.read<SessionBloc>();
    final info = sessionBloc.state.sessions[widget.sessionId];
    final projectName = info?.project ?? widget.sessionId;

    return Column(
      children: [
        _buildHeader(projectName, info),
        Expanded(
          child: BlocBuilder<SessionChatBloc, SessionChatState>(
            builder: (context, state) {
              final messages = state.messagesFor(widget.sessionId);
              if (messages.isEmpty) {
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
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return TerminalMessage(message: messages[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String projectName, SessionInfo? info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}
