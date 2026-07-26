import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import '../../generated/agent.dart';
import '../../providers/chat_providers.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

enum AgentState { idle, thinking, running }

AgentState resolveAgentState(String? raw) {
  switch (raw) {
    case 'thinking':
      return AgentState.thinking;
    case 'tool_use':
      return AgentState.running;
    default:
      return AgentState.idle;
  }
}

Color agentStateColor(AgentState state) => switch (state) {
      AgentState.idle => SpaceNotesTheme.dim,
      AgentState.thinking => SpaceNotesTheme.accent2,
      AgentState.running => SpaceNotesTheme.accent,
    };

String agentStateLabel(AgentState state) => switch (state) {
      AgentState.idle => 'IDLE',
      AgentState.thinking => 'THINKING',
      AgentState.running => 'TOOL · RUN',
    };

String agentBaseName(String agentKey) {
  final idx = agentKey.indexOf('@');
  return idx < 0 ? agentKey : agentKey.substring(0, idx);
}

String agentHostPart(String agentKey) {
  final idx = agentKey.indexOf('@');
  return idx < 0 ? '' : agentKey.substring(idx + 1);
}

String agentTimeAgo(Int64 ts) {
  final dt = timestampToDateTime(ts);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

String agentContextUsage(int used, int window) {
  return '${_fmtTokens(used)}/${_fmtTokens(window)}';
}

String _fmtTokens(int n) {
  if (n >= 1000000) {
    final m = n / 1000000;
    return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}m';
  }
  if (n >= 1000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
  }
  return '$n';
}

class AgentRowContent extends StatelessWidget {
  final int index;
  final Agent agent;
  final AgentState state;
  final bool showHost;
  final bool isActive;
  final EdgeInsets padding;

  const AgentRowContent({
    super.key,
    required this.index,
    required this.agent,
    required this.state,
    this.showHost = true,
    this.isActive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: -padding.left,
              top: -padding.top,
              bottom: -padding.bottom,
              child: const _LeftRule(),
            ),
          Row(
            children: [
              SizedBox(
                width: 28,
                child: SnUiText(
                  index.toString().padLeft(2, '0'),
                  color: SpaceNotesTheme.dim,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _NameBlock(
                  agent: agent,
                  showHost: showHost,
                  state: state,
                ),
              ),
              const SizedBox(width: 12),
              _StateTail(state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  final Agent agent;
  final bool showHost;
  final AgentState state;

  const _NameBlock({
    required this.agent,
    required this.showHost,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final base = agentBaseName(agent.id);
    final host = agentHostPart(agent.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            StateDot(state: state),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                base,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 14,
                  color: SpaceNotesTheme.fg,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showHost && host.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  host,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 10,
                    color: SpaceNotesTheme.dim,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _MetaLine(agent: agent),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final Agent agent;
  const _MetaLine({required this.agent});

  @override
  Widget build(BuildContext context) {
    final hasCtx = agent.contextWindow.toInt() > 0;
    final ctxValue = hasCtx
        ? agentContextUsage(
            agent.contextUsed.toInt(),
            agent.contextWindow.toInt(),
          )
        : null;

    final spans = <InlineSpan>[
      _metaLabel('REG'),
      _metaValue(' ${agentTimeAgo(agent.createdAt)}'),
      _metaLabel('   SEEN'),
      _metaValue(' ${agentTimeAgo(agent.lastSeen)}'),
      if (ctxValue != null) ...[
        _metaLabel('   CTX'),
        _metaValue(' $ctxValue'),
      ],
    ];

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  TextSpan _metaLabel(String text) => TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.dim,
          letterSpacing: 0.4,
        ),
      );

  TextSpan _metaValue(String text) => TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 10,
          color: SpaceNotesTheme.muted,
          letterSpacing: 0.4,
        ),
      );
}

class _LeftRule extends StatelessWidget {
  const _LeftRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      color: SpaceNotesTheme.accent,
    );
  }
}

class _StateTail extends StatelessWidget {
  final AgentState state;
  const _StateTail({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          agentStateLabel(state),
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: agentStateColor(state),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '›',
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 12,
            color: SpaceNotesTheme.dim,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class StateDot extends StatefulWidget {
  final AgentState state;
  const StateDot({super.key, required this.state});

  @override
  State<StateDot> createState() => _StateDotState();
}

class _StateDotState extends State<StateDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.state != AgentState.idle) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StateDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != AgentState.idle && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.state == AgentState.idle && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = agentStateColor(widget.state);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity = widget.state == AgentState.idle
            ? 1.0
            : 0.35 + (1.0 - 0.35) * _controller.value;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}
