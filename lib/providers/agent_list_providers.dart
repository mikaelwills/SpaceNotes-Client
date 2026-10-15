import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/agent.dart';
import '../generated/message.dart';
import 'chat_providers.dart';
import 'notes_providers.dart';

class LastReadNotifier extends StateNotifier<LastReadState> {
  LastReadNotifier() : super(const LastReadState.loading()) {
    _load();
  }

  static const _prefsKey = 'agent_last_read_v1';
  static const _baselineKey = 'agent_last_read_baseline_v1';

  void markRead(String agentId, int micros) {
    if (!state.loaded) return;
    if ((state.readAt[agentId] ?? 0) >= micros) return;
    state = state.copyWith(readAt: {...state.readAt, agentId: micros});
    _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var baseline = prefs.getInt(_baselineKey);
    if (baseline == null) {
      baseline = DateTime.now().microsecondsSinceEpoch;
      await prefs.setInt(_baselineKey, baseline);
    }
    final parsed = <String, int>{};
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v is num) parsed[k] = v.toInt();
          });
        }
      } catch (_) {}
    }
    state = LastReadState(baseline: baseline, readAt: parsed);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.readAt));
  }
}

class LastReadState {
  final int? baseline;
  final Map<String, int> readAt;

  const LastReadState({required this.baseline, required this.readAt});

  const LastReadState.loading()
      : baseline = null,
        readAt = const {};

  bool get loaded => baseline != null;

  int readMarkFor(String agentId) => readAt[agentId] ?? baseline ?? 0;

  LastReadState copyWith({Map<String, int>? readAt}) =>
      LastReadState(baseline: baseline, readAt: readAt ?? this.readAt);
}

final lastReadProvider = StateNotifierProvider<LastReadNotifier, LastReadState>(
  (ref) => LastReadNotifier(),
);

const _nonReplySources = {chatControlSource, 'progress', 'notice'};

bool isAgentReply(Message m) =>
    m.role != 'user' && !_nonReplySources.contains(m.source);

final latestReplyByAgentProvider = Provider<Map<String, Message>>((ref) {
  final client = ref.watch(chatClientProvider);
  if (client == null) return const {};
  final rows = watchListenable(ref, client.message.rows);
  final latest = <String, Message>{};
  for (final m in rows) {
    if (!isAgentReply(m)) continue;
    final current = latest[m.agentId];
    if (current == null || m.createdAt > current.createdAt) {
      latest[m.agentId] = m;
    }
  }
  return latest;
});

final agentUnreadProvider = Provider.family<bool, String>((ref, agentId) {
  final lastRead = ref.watch(lastReadProvider);
  if (!lastRead.loaded) return false;
  final reply = ref
      .watch(latestReplyByAgentProvider.select((m) => m[agentId]?.createdAt));
  if (reply == null) return false;
  return reply.toInt() > lastRead.readMarkFor(agentId);
});

final agentReplyPreviewProvider =
    Provider.family<String?, String>((ref, agentId) {
  final text =
      ref.watch(latestReplyByAgentProvider.select((m) => m[agentId]?.text));
  if (text == null) return null;
  for (final raw in text.split('\n')) {
    final line = raw
        .replaceFirst(RegExp(r'^[\s#>*\-]+'), '')
        .replaceAll('**', '')
        .trim();
    if (line.isNotEmpty) return line;
  }
  return null;
});

final agentWorkingProvider = Provider.family<bool, String>((ref, agentId) {
  final state =
      ref.watch(agentActivityProvider(agentId).select((a) => a?.state));
  return state == 'thinking' || state == 'tool_use';
});

class CollapsedHostsNotifier extends StateNotifier<Set<String>> {
  CollapsedHostsNotifier() : super(const {}) {
    _load();
  }

  static const _prefsKey = 'agent_collapsed_hosts_v1';

  void toggle(String host) {
    state =
        state.contains(host) ? ({...state}..remove(host)) : {...state, host};
    _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored != null) state = stored.toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state.toList());
  }
}

final collapsedHostsProvider =
    StateNotifierProvider<CollapsedHostsNotifier, Set<String>>(
  (ref) => CollapsedHostsNotifier(),
);

class AgentHostGroup {
  final String host;
  final List<Agent> agents;
  const AgentHostGroup(this.host, this.agents);
}

class AgentListSections {
  final List<Agent> attention;
  final List<AgentHostGroup> groups;
  const AgentListSections(this.attention, this.groups);
}

final agentListSectionsProvider = Provider<AgentListSections>((ref) {
  final agents = ref.watch(filteredAgentsProvider);
  final attention = <Agent>[];
  final byHost = <String, List<Agent>>{};
  for (final a in agents) {
    final needsLook = ref.watch(agentUnreadProvider(a.id)) ||
        ref.watch(agentWorkingProvider(a.id));
    if (needsLook) {
      attention.add(a);
    } else {
      (byHost[a.host] ??= []).add(a);
    }
  }
  final hosts = byHost.keys.toList()
    ..sort((a, b) {
      final ra = hostRank(a);
      final rb = hostRank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return AgentListSections(
    attention,
    [for (final h in hosts) AgentHostGroup(h, byHost[h]!)],
  );
});
