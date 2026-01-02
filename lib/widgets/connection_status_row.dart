import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spacenotes_client/blocs/chat/chat_bloc.dart';
import 'package:spacenotes_client/blocs/chat/chat_state.dart';
import '../theme/spacenotes_theme.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;

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
    final connectionBloc = context.read<ConnectionBloc>();
    final openCodeClient = connectionBloc.openCodeClient;
    final modelName = openCodeClient.modelDisplayName;

    return BlocBuilder<ConnectionBloc, connection_states.ConnectionState>(
      builder: (context, connectionState) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, chatState) {
              final isWorking = chatState is ChatReady && chatState.isWorking;
              final sessionStatus = chatState is ChatReady ? chatState.sessionStatus : null;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildConnectionIndicator(connectionState),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/provider-list'),
                        child: Text(
                          modelName,
                          style: SpaceNotesTextStyles.terminal.copyWith(
                            fontSize: 13,
                            color: SpaceNotesTheme.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sessionStatus != null && sessionStatus.isRetrying) ...[
                    Text(
                      sessionStatus.displayMessage,
                      style: SpaceNotesTextStyles.terminal.copyWith(
                        fontSize: 11,
                        color: SpaceNotesTheme.warning,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ] else if (isWorking) ...[
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildConnectionIndicator(connection_states.ConnectionState state) {
    Color color;
    bool shouldPulse = false;

    if (state is connection_states.Connected) {
      color = SpaceNotesTheme.success;
      shouldPulse = true;
    } else if (state is connection_states.Reconnecting) {
      color = SpaceNotesTheme.warning;
    } else {
      color = SpaceNotesTheme.error;
    }

    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (shouldPulse) {
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
