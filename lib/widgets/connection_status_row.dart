import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/notes_providers.dart';
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

    final lastSeenMicros = agent?.lastSeen.toInt();

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
          if (lastSeenMicros != null) ...[
            const SizedBox(width: 8),
            _LastSeenLabel(microsSinceEpoch: lastSeenMicros),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _A2aToggle(),
          const SizedBox(width: 12),
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

/// Ticks itself so the relative time doesn't freeze — the agent row only
/// rebuilds on state changes, which for an idle agent may never happen.
class _LastSeenLabel extends StatefulWidget {
  const _LastSeenLabel({required this.microsSinceEpoch});

  final int microsSinceEpoch;

  @override
  State<_LastSeenLabel> createState() => _LastSeenLabelState();
}

class _LastSeenLabelState extends State<_LastSeenLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _fmtLastSeen(widget.microsSinceEpoch);
    if (label == null) return const SizedBox.shrink();
    return SnUiText(
      '· $label',
      color: SpaceNotesTheme.dim,
      fontSize: 10,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Relative age of the agent's last heartbeat. Heartbeats persist at most
/// every 5 minutes server-side, so this is coarse by design.
String? _fmtLastSeen(int? microsSinceEpoch) {
  if (microsSinceEpoch == null || microsSinceEpoch <= 0) return null;

  final seen = DateTime.fromMicrosecondsSinceEpoch(microsSinceEpoch);
  final elapsed = DateTime.now().difference(seen);
  if (elapsed.isNegative) return 'now';

  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
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

class _A2aToggle extends ConsumerWidget {
  const _A2aToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(a2aEnabledProvider);
    final color = switch (enabled) {
      null => SpaceNotesTheme.dim,
      true => SpaceNotesTheme.online,
      false => SpaceNotesTheme.offline,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled == null
          ? null
          : () {
              final client = ref.read(chatClientProvider);
              client?.reducers.setA2aEnabled(enabled: !enabled);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              color: color,
            ),
            const SizedBox(width: 8),
            SnUiText(
              'a2a',
              color: color,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ],
        ),
      ),
    );
  }
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
