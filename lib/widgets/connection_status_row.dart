import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'primitives/primitives.dart';

class ConnectionStatusRow extends ConsumerWidget {
  const ConnectionStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetSession = ref.watch(targetSessionProvider);
    final activity = ref.watch(sessionActivityProvider(targetSession));

    final state = activity?.state ?? 'idle';
    final isActive = state == 'thinking' || state == 'tool_use';

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
              targetSession,
              color: SpaceNotesTheme.muted,
              fontSize: 10,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: isActive
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Pulsar(),
                const SizedBox(width: 8),
                SnUiText(
                  state == 'thinking' ? 'thinking' : 'running',
                  color: SpaceNotesTheme.accent2,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ],
            )
          : const SnUiText(
              'idle',
              color: SpaceNotesTheme.dim,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
    );
  }
}

class _Pulsar extends StatefulWidget {
  const _Pulsar();

  @override
  State<_Pulsar> createState() => _PulsarState();
}

class _PulsarState extends State<_Pulsar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
        final opacity = 0.35 + (1.0 - 0.35) * _controller.value;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 5,
            height: 5,
            color: SpaceNotesTheme.accent2,
          ),
        );
      },
    );
  }
}
