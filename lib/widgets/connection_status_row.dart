import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/chat/chat_bloc.dart';
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
        final isWorking = chatState is ChatReady && chatState.isWorking;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildConnectionIndicator(isConnected),
                  const SizedBox(width: 8),
                  Text(
                    'Claude Code',
                    style: SpaceNotesTextStyles.terminal.copyWith(
                      fontSize: 13,
                      color: SpaceNotesTheme.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isWorking) ...[
                SizedBox(
                  width: 70,
                  child: AnimatedDots(
                    textStyle: SpaceNotesTextStyles.terminal.copyWith(
                      fontSize: 11,
                      color: SpaceNotesTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
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
