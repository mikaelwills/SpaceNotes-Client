import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../../blocs/desktop_notes/desktop_notes_event.dart';
import '../../generated/agent.dart';
import '../../providers/chat_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/notes_providers.dart';
import '../../screens/agent_chat.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';
import '../agents/agent_row_content.dart';

class DesktopAgentsLayout extends ConsumerWidget {
  final String? activeAgentId;

  const DesktopAgentsLayout({super.key, this.activeAgentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
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
                const _ColumnHeader(),
                Expanded(
                  child: agents.isEmpty
                      ? const _EmptyList()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: agents.length,
                          itemBuilder: (context, index) {
                            final agent = agents[index];
                            final isActive = agent.id == activeAgentId;
                            return _AgentRow(
                              index: index + 1,
                              agent: agent,
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
          child: activeAgentId == null
              ? const _EmptyPane()
              : AgentChatScreen(
                  key: ValueKey(activeAgentId),
                  agentId: activeAgentId!,
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
                const SnMicroLabel('mcp · agents'),
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
                      TextSpan(text: 'Agents'),
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
          const SnIconButton(
            icon: Icon(Icons.terminal_outlined),
            onPressed: null,
            active: true,
            tooltip: 'agents',
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
        child: SnMicroLabel('no agents connected'),
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
          SnMicroLabel('select an agent from the sidebar'),
        ],
      ),
    );
  }
}

class _AgentRow extends ConsumerWidget {
  final int index;
  final Agent agent;
  final bool isActive;

  const _AgentRow({
    required this.index,
    required this.agent,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(agentActivityProvider(agent.id));
    final state = resolveAgentState(activity?.state);

    return Material(
      color: isActive
          ? SpaceNotesTheme.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.go('/notes/sessions/${Uri.encodeComponent(agent.id)}'),
        child: AgentRowContent(
          index: index,
          agent: agent,
          state: state,
          showHost: true,
          isActive: isActive,
        ),
      ),
    );
  }
}
