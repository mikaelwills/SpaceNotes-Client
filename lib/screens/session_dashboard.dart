import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/session.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/primitives.dart';
import '../widgets/swipe_action.dart';

class SessionDashboard extends ConsumerWidget {
  const SessionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final isConnected = ref.watch(spacetimeConnectedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          count: sessions.length,
          onClearAll:
              sessions.isEmpty ? null : () => _confirmClearAll(context, ref),
        ),
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
                      key: ValueKey(session.id),
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

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceNotesTheme.bgAlt,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: SpaceNotesTheme.hairline),
        ),
        title: const Text(
          'Clear all sessions?',
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontSans,
            fontSize: 16,
            color: SpaceNotesTheme.fg,
          ),
        ),
        content: const Text(
          'Wipes every session, all chat history, all tool events. Live sessions will reregister automatically. This cannot be undone.',
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontSans,
            fontSize: 13,
            color: SpaceNotesTheme.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: SpaceNotesTheme.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear all',
              style: TextStyle(color: SpaceNotesTheme.offline),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = ref.read(spacetimeClientProvider);
    if (client == null) return;
    await client.reducers.clearAllSessions();
  }
}

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback? onClearAll;
  const _Header({required this.count, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SnMicroLabel('mcp · sessions'),
          const Spacer(),
          SnUiText(
            '$count / ∞',
            color: SpaceNotesTheme.muted,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
          if (onClearAll != null) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: onClearAll,
              borderRadius: BorderRadius.circular(2),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: SpaceNotesTheme.muted,
                ),
              ),
            ),
          ],
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

class _SessionRow extends ConsumerStatefulWidget {
  final int index;
  final Session session;
  final bool showHost;

  const _SessionRow({
    super.key,
    required this.index,
    required this.session,
    required this.showHost,
  });

  @override
  ConsumerState<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends ConsumerState<_SessionRow>
    with SingleTickerProviderStateMixin {
  double _swipeOffset = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const double _actionButtonWidth = 60;
  static const double _maxSwipe = 60;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(sessionActivityProvider(widget.session.id));
    final targetSession = ref.watch(targetSessionProvider);
    final state = _resolveState(activity?.state);
    final isActive = widget.session.id == targetSession;

    final showAction = _swipeOffset < 0 || _animationController.isAnimating;
    final rowBg = isActive
        ? Color.alphaBlend(
            SpaceNotesTheme.accent.withValues(alpha: 0.06),
            SpaceNotesTheme.bg,
          )
        : SpaceNotesTheme.bg;
    return Stack(
      children: [
        if (showAction)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SwipeAction(
                  icon: Icons.delete_outline,
                  label: 'delete',
                  color: SpaceNotesTheme.offline,
                  width: _actionButtonWidth,
                  onTap: () {
                    _animateToOffset(0);
                    _deleteSession();
                  },
                ),
              ],
            ),
          ),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final offset = _animationController.isAnimating
                ? _animation.value
                : _swipeOffset;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: RawGestureDetector(
            gestures: {
              _LeftOnlyHorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _LeftOnlyHorizontalDragGestureRecognizer>(
                () => _LeftOnlyHorizontalDragGestureRecognizer(),
                (_LeftOnlyHorizontalDragGestureRecognizer instance) {
                  instance
                    ..onUpdate = (details) {
                      setState(() {
                        _swipeOffset = (_swipeOffset + details.delta.dx)
                            .clamp(-_maxSwipe, 0);
                      });
                    }
                    ..onEnd = (details) {
                      if (_swipeOffset < -_maxSwipe / 2) {
                        _animateToOffset(-_maxSwipe);
                      } else {
                        _animateToOffset(0);
                      }
                    };
                },
              ),
            },
            child: Material(
              color: rowBg,
              child: InkWell(
                onTap: _handleTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: SpaceNotesTheme.hairline, width: 1),
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
                              widget.index.toString().padLeft(2, '0'),
                              color: SpaceNotesTheme.dim,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                              child: _NameBlock(
                            session: widget.session,
                            showHost: widget.showHost,
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
            ),
          ),
        ),
      ],
    );
  }

  void _handleTap() {
    if (_swipeOffset != 0) {
      _animateToOffset(0);
      return;
    }
    HapticFeedback.selectionClick();
    context.push(
        '/notes/sessions/${Uri.encodeComponent(widget.session.id)}');
  }

  void _animateToOffset(double target) {
    _animation = Tween<double>(begin: _swipeOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0).then((_) {
      setState(() => _swipeOffset = target);
    });
  }

  Future<void> _deleteSession() async {
    HapticFeedback.mediumImpact();
    final client = ref.read(spacetimeClientProvider);
    if (client == null) return;
    await client.reducers.deleteSession(sessionId: widget.session.id);
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

class _LeftOnlyHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    return estimate.pixelsPerSecond.dx.abs() > minVelocity;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
      PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved < -kTouchSlop;
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
            if (session.contextWindow.toInt() > 0) ...[
              const SizedBox(width: 14),
              _MetaPair(
                label: 'ctx',
                value: _formatContextUsage(
                  session.contextUsed.toInt(),
                  session.contextWindow.toInt(),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatContextUsage(int used, int window) {
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
