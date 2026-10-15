import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/agent.dart';
import '../../providers/agent_list_providers.dart';
import '../../providers/chat_providers.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

typedef AgentListRowBuilder = Widget Function(
  BuildContext context,
  Agent agent,
  int index, {
  required bool attention,
});

class AgentSectionedList extends ConsumerWidget {
  final AgentListRowBuilder rowBuilder;

  const AgentSectionedList({super.key, required this.rowBuilder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(agentListSectionsProvider);
    final collapsed = ref.watch(collapsedHostsProvider);
    final filtering = ref.watch(agentFilterProvider).trim().isNotEmpty;
    final entries = _buildEntries(sections, collapsed, filtering);

    return ListView.builder(
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
              onTap: () =>
                  ref.read(collapsedHostsProvider.notifier).toggle(host),
            ),
          _RowEntry(:final agent, :final index, :final attention) =>
            KeyedSubtree(
              key: ValueKey('${attention ? 'a' : 'h'}:${agent.id}'),
              child: rowBuilder(context, agent, index, attention: attention),
            ),
        };
      },
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
