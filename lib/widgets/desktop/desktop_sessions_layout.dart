import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../generated/session.dart';
import '../../providers/chat_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/notes_providers.dart';
import '../../screens/session_chat.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

class DesktopSessionsLayout extends ConsumerWidget {
  final String? activeSessionId;

  const DesktopSessionsLayout({super.key, this.activeSessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final isConnected = ref.watch(spacetimeConnectedProvider);

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Container(
            decoration: const BoxDecoration(
              color: SpaceNotesTheme.bgAlt,
              border: Border(
                right: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(isConnected: isConnected),
                _ColumnHeader(),
                Expanded(
                  child: sessions.isEmpty
                      ? const _EmptyList()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final isActive = session.id == activeSessionId;
                            return _SessionRow(
                              index: index + 1,
                              session: session,
                              isActive: isActive,
                            );
                          },
                        ),
                ),
                const _Footer(),
              ],
            ),
          ),
        ),
        Expanded(
          child: activeSessionId == null
              ? const _EmptyPane()
              : SessionChatScreen(
                  key: ValueKey(activeSessionId),
                  sessionId: activeSessionId!,
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool isConnected;
  const _Header({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SnMicroLabel('mcp · sessions'),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: SpaceNotesTheme.fontSans,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: SpaceNotesTheme.fg,
                      letterSpacing: -0.4,
                      height: 1,
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
              ],
            ),
          ),
          SnSyncDot(
            state: isConnected ? SnSyncState.synced : SnSyncState.offline,
            label: isConnected ? 'connected' : 'offline',
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Consumer(
            builder: (context, ref, _) => SnIconButton(
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () => _createNote(context, ref),
              tooltip: 'new note',
            ),
          ),
          const SizedBox(width: 4),
          SnIconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _createFolder(context),
            tooltip: 'new folder',
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 16,
            color: SpaceNotesTheme.hairlineStrong,
          ),
          const SizedBox(width: 14),
          SnIconButton(
            icon: const Icon(Icons.notes_outlined),
            onPressed: () => context.go('/notes'),
            tooltip: 'notes',
          ),
          const SizedBox(width: 4),
          SnIconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.go('/notes/chat'),
            tooltip: 'chat',
          ),
          const SizedBox(width: 4),
          SnIconButton(
            icon: const Icon(Icons.terminal_outlined),
            onPressed: null,
            active: true,
            tooltip: 'sessions',
          ),
          const Spacer(),
          SnIconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
            tooltip: 'settings',
          ),
        ],
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notesRepositoryProvider);
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final notePath = 'All Notes/Untitled-$timestamp.md';
    final noteId = await repo.createNote(notePath, '');
    if (noteId != null && context.mounted) {
      context.read<DesktopNotesBloc>().add(OpenNote(noteId));
      context.go('/notes');
    }
  }

  void _createFolder(BuildContext context) {
    context.go('/notes');
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
          bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
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

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SnMicroLabel('no sessions connected'),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal_outlined,
            size: 48,
            color: SpaceNotesTheme.dim,
          ),
          SizedBox(height: 20),
          SnMicroLabel('select a session from the sidebar'),
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  final int index;
  final Session session;
  final bool isActive;

  const _SessionRow({
    required this.index,
    required this.session,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(sessionActivityProvider(session.id));
    final state = _resolveState(activity?.state);
    final base = _baseName(session.id);
    final host = _hostPart(session.id);

    return Material(
      color: isActive
          ? SpaceNotesTheme.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.go('/notes/sessions/${Uri.encodeComponent(session.id)}'),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    child: SnUiText(
                      index.toString().padLeft(2, '0'),
                      color: SpaceNotesTheme.dim,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                                  fontSize: 13,
                                  color: SpaceNotesTheme.fg,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (host.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
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
                  ),
                  const SizedBox(width: 10),
                  SnUiText(
                    _stateLabel(state),
                    color: _stateColor(state),
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ],
              ),
            ),
            if (isActive)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 2,
                  child: ColoredBox(color: SpaceNotesTheme.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SessionState { idle, thinking, running }

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
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
