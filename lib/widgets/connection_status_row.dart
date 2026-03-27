import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/tool_event.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';

class ConnectionStatusRow extends StatefulWidget {
  const ConnectionStatusRow({super.key});

  @override
  State<ConnectionStatusRow> createState() => _ConnectionStatusRowState();
}

class _ConnectionStatusRowState extends State<ConnectionStatusRow>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final isConnected = chatState is ChatReady && chatState.isConnected;
        final targetSession = chatState is ChatReady
            ? chatState.targetSession
            : 'note-assistant';
        final toolEvent = chatState is ChatReady
            ? chatState.activeToolEvent
            : null;

        final displayName = targetSession
            .split('-')
            .map((w) =>
                w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildConnectionIndicator(isConnected),
                        const SizedBox(width: 8),
                        Text(
                          displayName,
                          style: SpaceNotesTextStyles.terminal.copyWith(
                            fontSize: 13,
                            color: SpaceNotesTheme.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    _buildToolRow(toolEvent),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () =>
                    context.read<ChatBloc>().add(ClearMessages()),
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: SpaceNotesTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionIndicator(bool isConnected) {
    final color = isConnected ? SpaceNotesTheme.success : SpaceNotesTheme.error;

    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (isConnected) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: dot,
          );
        },
      );
    }

    return dot;
  }

  Widget _buildToolRow(ToolEvent? toolEvent) {
    return AnimatedOpacity(
      opacity: toolEvent != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 2),
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
            if (toolEvent != null) ...[
              Text(
                _toolLabel(toolEvent.tool.toLowerCase()),
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 11,
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _formatToolDetail(toolEvent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 11,
                    color: SpaceNotesTheme.textSecondary
                        .withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatToolDetail(ToolEvent event) {
    final input = event.input;

    final command = input['command'];
    if (command != null && command is String && command.isNotEmpty) {
      final firstWord = command.contains(' ')
          ? command.substring(0, command.indexOf(' '))
          : command;
      return firstWord;
    }

    final filePath = input['file_path'] ?? input['path'] ?? input['filePath'];
    if (filePath != null && filePath is String && filePath.isNotEmpty) {
      return filePath.contains('/')
          ? filePath.substring(filePath.lastIndexOf('/') + 1)
          : filePath;
    }

    final pattern = input['pattern'];
    if (pattern != null && pattern is String && pattern.isNotEmpty) {
      return pattern.length > 30
          ? '${pattern.substring(0, 30)}...'
          : pattern;
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

class AnimatedDots extends StatefulWidget {
  final TextStyle textStyle;

  const AnimatedDots({super.key, required this.textStyle});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dotCount = _animation.value;
        final dots = '.' * dotCount;
        return Text(
          'working$dots',
          style: widget.textStyle,
        );
      },
    );
  }
}
