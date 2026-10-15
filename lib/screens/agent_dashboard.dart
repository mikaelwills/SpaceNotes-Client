import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/agent.dart';
import '../providers/agent_list_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/primitives.dart';
import '../widgets/agents/agent_filter_bar.dart';
import '../widgets/agents/agent_row_content.dart';
import '../widgets/swipe_action.dart';

class AgentDashboard extends ConsumerWidget {
  const AgentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final sections = ref.watch(agentListSectionsProvider);
    final collapsed = ref.watch(collapsedHostsProvider);
    final filtering = ref.watch(agentFilterProvider).trim().isNotEmpty;
    final isConnected = ref.watch(spacetimeConnectedProvider);
    final entries = _buildEntries(sections, collapsed, filtering);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          count: agents.length,
          onClearAll:
              agents.isEmpty ? null : () => _confirmClearAll(context, ref),
        ),
        Expanded(
          child: agents.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return switch (entries[index]) {
                      _SectionEntry(:final label, :final count) =>
                        _SectionHeader(label: label, count: count),
                      _HostEntry(:final host, :final count, :final collapsed) =>
                        _SectionHeader(
                          label: host,
                          count: count,
                          collapsed: collapsed,
                          onTap: () => ref
                              .read(collapsedHostsProvider.notifier)
                              .toggle(host),
                        ),
                      _RowEntry(:final agent, :final index, :final attention) =>
                        _AgentRow(
                          key: ValueKey('${attention ? 'a' : 'h'}:${agent.id}'),
                          index: index,
                          agent: agent,
                          showHost: attention,
                          showPreview: attention,
                        ),
                    };
                  },
                ),
        ),
        const AgentFilterBar(),
        _Footer(isConnected: isConnected),
      ],
    );
  }

  List<_Entry> _buildEntries(
    AgentListSections sections,
    Set<String> collapsed,
    bool filtering,
  ) {
    final entries = <_Entry>[];
    var index = 0;
    if (sections.attention.isNotEmpty) {
      entries.add(_SectionEntry('new · working', sections.attention.length));
      for (final a in sections.attention) {
        entries.add(_RowEntry(a, ++index, attention: true));
      }
    }
    for (final group in sections.groups) {
      final isCollapsed = !filtering && collapsed.contains(group.host);
      entries.add(_HostEntry(group.host, group.agents.length, isCollapsed));
      if (isCollapsed) {
        index += group.agents.length;
        continue;
      }
      for (final a in group.agents) {
        entries.add(_RowEntry(a, ++index, attention: false));
      }
    }
    return entries;
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
          'Clear all agents?',
          style: TextStyle(
            fontFamily: SpaceNotesTheme.fontSans,
            fontSize: 16,
            color: SpaceNotesTheme.fg,
          ),
        ),
        content: const Text(
          'Wipes every agent, all chat history, all tool events. Live agents will reregister automatically. This cannot be undone.',
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
    final client = ref.read(chatClientProvider);
    if (client == null) return;
    await client.reducers.clearAllAgents();
  }
}

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback? onClearAll;
  const _Header({required this.count, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kStatusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SnMicroLabel('mcp · agents'),
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

sealed class _Entry {}

class _SectionEntry extends _Entry {
  final String label;
  final int count;
  _SectionEntry(this.label, this.count);
}

class _HostEntry extends _Entry {
  final String host;
  final int count;
  final bool collapsed;
  _HostEntry(this.host, this.count, this.collapsed);
}

class _RowEntry extends _Entry {
  final Agent agent;
  final int index;
  final bool attention;
  _RowEntry(this.agent, this.index, {required this.attention});
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool? collapsed;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.label,
    required this.count,
    this.collapsed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bgAlt,
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (collapsed != null) ...[
            Icon(
              collapsed! ? Icons.chevron_right : Icons.expand_more,
              size: 14,
              color: SpaceNotesTheme.muted,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SnMicroLabel(label.isEmpty ? 'local' : label, fontSize: 10),
          ),
          SnUiText(
            '$count',
            color: SpaceNotesTheme.muted,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ],
      ),
    );
    if (onTap == null) return header;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: header),
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
          SnMicroLabel('no agents connected'),
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

class _AgentRow extends ConsumerStatefulWidget {
  final int index;
  final Agent agent;
  final bool showHost;
  final bool showPreview;

  const _AgentRow({
    super.key,
    required this.index,
    required this.agent,
    required this.showHost,
    required this.showPreview,
  });

  @override
  ConsumerState<_AgentRow> createState() => _AgentRowState();
}

class _AgentRowState extends ConsumerState<_AgentRow>
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
    final activity = ref.watch(agentActivityProvider(widget.agent.id));
    final targetAgent = ref.watch(targetAgentProvider);
    final state = resolveAgentState(activity?.state);
    final isActive = widget.agent.id == targetAgent;
    final unread = ref.watch(agentUnreadProvider(widget.agent.id));
    final reply = widget.showPreview
        ? ref.watch(
            latestReplyByAgentProvider.select((m) => m[widget.agent.id]?.text))
        : null;
    final preview = reply == null ? null : _previewLine(reply);

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
                    _deleteAgent();
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
                child: AgentRowContent(
                  index: widget.index,
                  agent: widget.agent,
                  state: state,
                  showHost: widget.showHost,
                  isActive: isActive,
                  unread: unread,
                  preview: preview,
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
    context.push('/agents/${Uri.encodeComponent(widget.agent.id)}');
  }

  void _animateToOffset(double target) {
    _animation = Tween<double>(begin: _swipeOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0).then((_) {
      setState(() => _swipeOffset = target);
    });
  }

  Future<void> _deleteAgent() async {
    HapticFeedback.mediumImpact();
    final client = ref.read(chatClientProvider);
    if (client == null) return;
    await client.reducers.deleteAgent(agentId: widget.agent.id);
  }
}

String? _previewLine(String text) {
  for (final raw in text.split('\n')) {
    final line = raw
        .replaceFirst(RegExp(r'^[\s#>*\-]+'), '')
        .replaceAll('**', '')
        .trim();
    if (line.isNotEmpty) return line;
  }
  return null;
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
