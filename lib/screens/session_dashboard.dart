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
import '../widgets/sessions/session_filter_bar.dart';
import '../widgets/sessions/session_row_content.dart';
import '../widgets/swipe_action.dart';

class SessionDashboard extends ConsumerWidget {
  const SessionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final filtered = ref.watch(filteredSessionsProvider);
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final session = filtered[index];
                    return _SessionRow(
                      key: ValueKey(session.id),
                      index: index + 1,
                      session: session,
                      showHost: true,
                    );
                  },
                ),
        ),
        const SessionFilterBar(),
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
    final state = resolveSessionState(activity?.state);
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
                child: SessionRowContent(
                  index: widget.index,
                  session: widget.session,
                  state: state,
                  showHost: widget.showHost,
                  isActive: isActive,
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
