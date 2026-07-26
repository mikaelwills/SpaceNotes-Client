import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'primitives/primitives.dart';

class ConnectionStatusRow extends ConsumerWidget {
  final String? agentId;

  const ConnectionStatusRow({super.key, this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String resolvedAgent = agentId ?? ref.watch(targetAgentProvider);
    final activity = ref.watch(agentActivityProvider(resolvedAgent));
    final agent = ref.watch(agentByIdProvider(resolvedAgent));

    final state = activity?.state ?? 'idle';
    final isActive = state == 'thinking' || state == 'tool_use';
    final label = switch (state) {
      'thinking' => 'thinking',
      'tool_use' => 'running',
      _ => 'idle',
    };
    final accent = isActive ? SpaceNotesTheme.accent2 : SpaceNotesTheme.dim;

    final ctxWindow = agent?.contextWindow.toInt() ?? 0;
    final ctxUsed = agent?.contextUsed.toInt() ?? 0;
    final ctxLabel = ctxWindow > 0
        ? '${_fmtTokens(ctxUsed)}/${_fmtTokens(ctxWindow)}'
        : null;

    return SnStatusLine(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '◆',
            style: TextStyle(
              color: SpaceNotesTheme.accent,
              fontSize: 10,
              fontFamily: SpaceNotesTheme.fontMono,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: SnUiText(
              resolvedAgent,
              color: SpaceNotesTheme.accent,
              fontSize: 10,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ctxLabel != null) ...[
            const SizedBox(width: 8),
            SnUiText(
              '· $ctxLabel',
              color: SpaceNotesTheme.dim,
              fontSize: 10,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateDot(color: accent, pulsing: isActive),
          const SizedBox(width: 8),
          SnUiText(
            label,
            color: accent,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ],
      ),
    );
  }
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

class _StateDot extends StatefulWidget {
  final Color color;
  final bool pulsing;

  const _StateDot({required this.color, required this.pulsing});

  @override
  State<_StateDot> createState() => _StateDotState();
}

class _StateDotState extends State<_StateDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.pulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _StateDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity =
            widget.pulsing ? 0.4 + (1.0 - 0.4) * _controller.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 5,
            height: 5,
            color: widget.color,
          ),
        );
      },
    );
  }
}
