import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSessions extends StateNotifier<Map<String, int>> {
  RecentSessions() : super(const {}) {
    _load();
  }

  void markUsed(String sessionId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = {...state, sessionId: now};
    _persist();
  }

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

final recentSessionsProvider =
    StateNotifierProvider<RecentSessions, Map<String, int>>(
  (ref) => RecentSessions(),
);
