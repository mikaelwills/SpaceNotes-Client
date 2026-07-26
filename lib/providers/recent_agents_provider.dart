import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentAgents extends StateNotifier<Map<String, int>> {
  RecentAgents() : super(const {}) {
    _load();
  }

  void markUsed(String agentId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = {...state, agentId: now};
    _persist();
  }

  // Key value kept as-is so existing users' recency history survives the rename.
  static const _prefsKey = 'recent_sessions_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final parsed = <String, int>{};
      decoded.forEach((k, v) {
        if (k is String && v is num) parsed[k] = v.toInt();
      });
      state = parsed;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }
}

final recentAgentsProvider =
    StateNotifierProvider<RecentAgents, Map<String, int>>(
  (ref) => RecentAgents(),
);
