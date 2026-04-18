import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/session.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/primitives.dart';

class SessionDashboard extends ConsumerWidget {
  const SessionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final isConnected = ref.watch(spacetimeConnectedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(count: sessions.length),
        const _ColumnHeader(),
        Expanded(
          child: sessions.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final base = _baseName(session.id);
                    final baseCount =
                        sessions.where((s) => _baseName(s.id) == base).length;
                    return _SessionRow(
                      index: index + 1,
                      session: session,
                      showHost: baseCount > 1,
                    );
                  },
                ),
        ),
        _Footer(isConnected: isConnected),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SnMicroLabel('mcp · sessions'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(text: 'Sessions'),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: SpaceNotesTheme.accent),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SnUiText(
                  '$count / ∞',
                  color: SpaceNotesTheme.muted,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Conversations that persist across devices and platforms. '
            'Tap to resume where you left off.',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 13,
              color: SpaceNotesTheme.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 28,
            child: SnMicroLabel('#', fontSize: 9),
          ),
          SizedBox(width: 14),
          Expanded(child: SnMicroLabel('agent / name', fontSize: 9)),
          SnMicroLabel('state', fontSize: 9),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory, size: 48, color: SpaceNotesTheme.dim),
          SizedBox(height: 16),
          SnMicroLabel('no sessions connected'),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool isConnected;
  const _Footer({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SnStatusDiamond('spacetimedb'),
          SnSyncDot(
            state: isConnected ? SnSyncState.synced : SnSyncState.offline,
            label: isConnected ? 'connected' : 'offline',
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  final int index;
  final Session session;
  final bool showHost;

  const _SessionRow({
    required this.index,
    required this.session,
    required this.showHost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(sessionActivityProvider(session.id));
    final targetSession = ref.watch(targetSessionProvider);
    final state = _resolveState(activity?.state);
    final isActive = session.id == targetSession;

    return Material(
      color: isActive
          ? SpaceNotesTheme.accent.withValues(alpha: 0.03)
          : Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push('/notes/sessions/${Uri.encodeComponent(session.id)}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
            ),
          ),
          child: Stack(
            children: [
              if (isActive)
                const Positioned(
                  left: -20,
                  top: -16,
                  bottom: -16,
                  child: _LeftRule(),
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
                    session: session,
                    showHost: showHost,
                    state: state,
                  )),
                  const SizedBox(width: 12),
                  _StateTail(state: state),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SessionState _resolveState(String? raw) {
    switch (raw) {
      case 'thinking':
        return _SessionState.thinking;
      case 'tool_use':
        return _SessionState.running;
      default:
        return _SessionState.idle;
    }
  }
}

class _LeftRule extends StatelessWidget {
  const _LeftRule();

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, color: SpaceNotesTheme.accent);
  }
}

class _NameBlock extends StatelessWidget {
  final Session session;
  final bool showHost;
  final _SessionState state;

  const _NameBlock({
    required this.session,
    required this.showHost,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final base = _baseName(session.id);
    final host = _hostPart(session.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StateDot(state: state),
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
        Row(
          children: [
            _MetaPair(label: 'reg', value: _timeAgo(session.createdAt)),
            const SizedBox(width: 14),
            _MetaPair(label: 'seen', value: _timeAgo(session.lastSeen)),
          ],
        ),
      ],
    );
  }
}

class _MetaPair extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.dim,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.muted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _StateDot extends StatefulWidget {
  final _SessionState state;
  const _StateDot({required this.state});

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
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.state != _SessionState.idle) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _StateDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != _SessionState.idle && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.state == _SessionState.idle && _controller.isAnimating) {
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
    final color = _stateColor(widget.state);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity = widget.state == _SessionState.idle
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

class _StateTail extends StatelessWidget {
  final _SessionState state;
  const _StateTail({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _stateLabel(state),
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: _stateColor(state),
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

enum _SessionState { idle, thinking, running }

Color _stateColor(_SessionState state) => switch (state) {
      _SessionState.idle => SpaceNotesTheme.dim,
      _SessionState.thinking => SpaceNotesTheme.accent2,
      _SessionState.running => SpaceNotesTheme.accent,
    };

String _stateLabel(_SessionState state) => switch (state) {
      _SessionState.idle => 'IDLE',
      _SessionState.thinking => 'THINKING',
      _SessionState.running => 'TOOL · RUN',
    };

String _baseName(String sessionKey) {
  final idx = sessionKey.indexOf('@');
  return idx < 0 ? sessionKey : sessionKey.substring(0, idx);
}

String _hostPart(String sessionKey) {
  final idx = sessionKey.indexOf('@');
  return idx < 0 ? '' : sessionKey.substring(idx + 1);
}

String _timeAgo(Int64 ts) {
  final dt = timestampToDateTime(ts);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
