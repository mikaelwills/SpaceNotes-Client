import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../blocs/session_chat/session_chat_bloc.dart';
import '../blocs/session_chat/session_chat_state.dart';
import '../models/tool_event.dart';
import '../services/space_channel_service.dart';
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
  StreamSubscription<ToolEvent>? _toolSub;
  Timer? _hideTimer;
  ToolEvent? _latestTool;
  bool _showToolRow = false;

  @override
  void initState() {
    super.initState();
    final spaceChannel = context.read<SpaceChannelService>();
    _toolSub = spaceChannel.toolEvents
        .where((e) => e.session == widget.sessionId)
        .listen(_onToolEvent);
  }

  @override
  void dispose() {
    _toolSub?.cancel();
    _hideTimer?.cancel();
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
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _showToolRow && _latestTool != null
              ? _buildToolRow(_latestTool!)
              : const SizedBox.shrink(),
        ),
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

  Widget _buildToolRow(ToolEvent event) {
    final display = _formatToolEvent(event);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.surface.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: SpaceNotesTheme.secondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
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
      ),
    );
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

  String _formatToolEvent(ToolEvent event) {
    final tool = event.tool.toLowerCase();
    final input = event.input;

    final command = input['command'];
    if (command != null && command is String && command.isNotEmpty) {
      final firstWord = command.contains(' ') ? command.substring(0, command.indexOf(' ')) : command;
      return 'bash $firstWord';
    }

    final filePath = input['file_path'] ?? input['path'] ?? input['filePath'];
    if (filePath != null && filePath is String && filePath.isNotEmpty) {
      final fileName = filePath.contains('/') ? filePath.substring(filePath.lastIndexOf('/') + 1) : filePath;
      final toolLabel = _toolLabel(tool);
      return '$toolLabel $fileName';
    }

    final pattern = input['pattern'];
    if (pattern != null && pattern is String && pattern.isNotEmpty) {
      final truncated = pattern.length > 30 ? '${pattern.substring(0, 30)}...' : pattern;
      return 'search "$truncated"';
    }

    final query = input['query'];
    if (query != null && query is String && query.isNotEmpty) {
      final truncated = query.length > 30 ? '${query.substring(0, 30)}...' : query;
      return '${_toolLabel(tool)} "$truncated"';
    }

    return _toolLabel(tool);
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
