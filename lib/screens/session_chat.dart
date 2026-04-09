import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/tool_status_row.dart';

class SessionChatScreen extends StatefulWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  final _messageListKey = GlobalKey<ChatMessageListState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<ChatBloc, ChatState>(
          bloc: GetIt.I<ChatBloc>(),
          buildWhen: (prev, curr) {
            if (prev is! ChatReady || curr is! ChatReady) return true;
            final prevInfo = prev.sessions[widget.sessionId];
            final currInfo = curr.sessions[widget.sessionId];
            return prevInfo?.activityState != currInfo?.activityState ||
                prevInfo?.recentToolEvents != currInfo?.recentToolEvents;
          },
          builder: (context, state) {
            final info = state is ChatReady ? state.sessions[widget.sessionId] : null;
            final projectName = widget.sessionId;
            return _buildHeader(projectName, info);
          },
        ),
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            bloc: GetIt.I<ChatBloc>(),
            listener: (context, state) {
              _messageListKey.currentState?.forceScrollToBottom();
            },
            listenWhen: (previous, current) {
              final prevLen = previous is ChatReady
                  ? previous.messagesFor(widget.sessionId).length
                  : 0;
              final currLen = current is ChatReady
                  ? current.messagesFor(widget.sessionId).length
                  : 0;
              return prevLen != currLen;
            },
            builder: (context, state) {
              final messages = state is ChatReady
                  ? state.messagesFor(widget.sessionId)
                  : const <dynamic>[];
              return ChatMessageList(
                key: _messageListKey,
                messages: List.from(messages),
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
                maxWidth: double.infinity,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String projectName, SessionInfo? sessionInfo) {
    final activityState = sessionInfo?.activityState ?? SessionActivityState.idle;
    final isActive = activityState != SessionActivityState.idle;
    final latestTool = sessionInfo?.recentToolEvents.isNotEmpty == true
        ? sessionInfo!.recentToolEvents.last
        : null;
    final isThinking = activityState == SessionActivityState.thinking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectName.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ToolStatusRow(
                  toolEvent: activityState == SessionActivityState.toolUse ? latestTool : null,
                  isThinking: isThinking,
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? SpaceNotesTheme.primary : SpaceNotesTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
