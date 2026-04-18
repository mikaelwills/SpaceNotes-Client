import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';

class ConnectionStatusRow extends ConsumerWidget {
  final String? sessionId;

  const ConnectionStatusRow({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String resolvedSession =
        sessionId ?? ref.watch(targetSessionProvider);
    final activity = ref.watch(sessionActivityProvider(resolvedSession));

    final state = activity?.state ?? 'idle';
    final label = switch (state) {
      'thinking' => 'THINKING',
      'tool_use' => 'TOOL · RUN',
      _ => 'IDLE',
    };
    final isActive = state == 'thinking' || state == 'tool_use';
    final accent = isActive ? SpaceNotesTheme.accent2 : SpaceNotesTheme.dim;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _SessionName(session: resolvedSession)),
          const SizedBox(width: 12),
          _StateBadge(label: label, color: accent, pulsing: isActive),
        ],
      ),
    );
  }
}

class _SessionName extends StatelessWidget {
  final String session;
  const _SessionName({required this.session});

  @override
  Widget build(BuildContext context) {
    final atIdx = session.indexOf('@');
    final base = atIdx < 0 ? session : session.substring(0, atIdx);
    final tail = atIdx < 0 ? '' : session.substring(atIdx);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 16,
          color: SpaceNotesTheme.fg,
          letterSpacing: 0.3,
          height: 1.0,
        ),
        children: [
          TextSpan(text: base),
          if (tail.isNotEmpty)
            TextSpan(
              text: tail,
              style: const TextStyle(color: SpaceNotesTheme.dim),
            ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool pulsing;

  const _StateBadge({
    required this.label,
    required this.color,
    required this.pulsing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StateDot(color: color, pulsing: pulsing),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 11,
            color: color,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
