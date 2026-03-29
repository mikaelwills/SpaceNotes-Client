import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../models/tool_event.dart';
import '../services/space_channel/session_activity_event.dart';
import '../services/space_channel/space_channel_service.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';
import '../widgets/terminal_message.dart';

class SessionChatScreen extends StatefulWidget {
  final String sessionId;

  const SessionChatScreen({super.key, required this.sessionId});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  final _scrollController = ScrollController();
  StreamSubscription<SessionActivityEvent>? _activitySub;
  Timer? _hideTimer;
  ToolEvent? _latestTool;
  bool _showToolRow = false;

  @override
  void initState() {
    super.initState();
    final spaceChannel = GetIt.I<SpaceChannelService>();
    _activitySub = spaceChannel.sessionActivity
        .where((a) => a.session == widget.sessionId && a.type == SessionActivityType.toolUse)
        .listen((a) => _onToolEvent(a.toolEvent!));
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    _hideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

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
            return prevInfo?.activityState != currInfo?.activityState;
          },
          builder: (context, state) {
            final info = state is ChatReady ? state.sessions[widget.sessionId] : null;
            final projectName = info?.project ?? widget.sessionId;
            return _buildHeader(projectName, info);
          },
        ),
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            bloc: GetIt.I<ChatBloc>(),
            listener: (context, state) {
              _scrollToBottom();
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
                  : <dynamic>[];
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
              return KeyboardDismissOnScroll(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return TerminalMessage(message: messages[index]);
                  },
                ),
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
    final showToolStatus = _showToolRow && _latestTool != null;
    final showThinking = activityState == SessionActivityState.thinking && !showToolStatus;

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
                AnimatedOpacity(
                  opacity: showToolStatus || showThinking ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: SpaceNotesTheme.secondary.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (showThinking)
                        Text(
                          'thinking...',
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 11,
                            color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      if (showToolStatus && _latestTool != null) ...[
                        Text(
                          _toolLabel(_latestTool!.tool.toLowerCase()),
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 11,
                            color: SpaceNotesTheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatToolDetail(_latestTool!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'FiraCode',
                              fontSize: 11,
                              color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ],
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
              color: isActive ? SpaceNotesTheme.primary : SpaceNotesTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onToolEvent(ToolEvent event) {
    _hideTimer?.cancel();
    setState(() {
      _latestTool = event;
      _showToolRow = true;
    });
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showToolRow = false);
      }
    });
  }

  String _formatToolDetail(ToolEvent event) {
    final input = event.input;

    final command = input['command'];
    if (command != null && command is String && command.isNotEmpty) {
      final firstWord = command.contains(' ') ? command.substring(0, command.indexOf(' ')) : command;
      return firstWord;
    }

    final filePath = input['file_path'] ?? input['path'] ?? input['filePath'];
    if (filePath != null && filePath is String && filePath.isNotEmpty) {
      return filePath.contains('/') ? filePath.substring(filePath.lastIndexOf('/') + 1) : filePath;
    }

    final pattern = input['pattern'];
    if (pattern != null && pattern is String && pattern.isNotEmpty) {
      return pattern.length > 30 ? '${pattern.substring(0, 30)}...' : pattern;
    }

    final query = input['query'];
    if (query != null && query is String && query.isNotEmpty) {
      return query.length > 30 ? '${query.substring(0, 30)}...' : query;
    }

    return '';
  }

  String _toolLabel(String tool) {
    const labels = {
      'read': 'read',
      'write': 'write',
      'bash': 'bash',
      'grep': 'search',
      'glob': 'find',
      'edit': 'edit',
      'agent': 'agent',
    };
    if (labels.containsKey(tool)) return labels[tool]!;
    if (tool.contains('spacenotes')) return 'spacenotes';
    if (tool.contains('__')) {
      final parts = tool.split('__');
      return parts.last;
    }
    return tool;
  }
}
