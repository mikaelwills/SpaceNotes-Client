import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouriteFolders extends StateNotifier<List<String>> {
  FavouriteFolders() : super(const []) {
    _load();
  }

  static const _prefsKey = 'favourite_folders_v1';

  void add(String path) {
    if (state.contains(path)) return;
    state = [...state, path];
    _persist();
  }

  void remove(String path) {
    if (!state.contains(path)) return;
    state = state.where((p) => p != path).toList();
    _persist();
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = List<String>.from(state);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
    _persist();
  }

  void syncWithExistingPaths(Set<String> existingPaths) {
    if (existingPaths.isEmpty) return;
    final filtered = state.where(existingPaths.contains).toList();
    if (filtered.length != state.length) {
      state = filtered;
      _persist();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = decoded.whereType<String>().toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }
}

final favouriteFoldersProvider =
    StateNotifierProvider<FavouriteFolders, List<String>>(
  (ref) => FavouriteFolders(),
);
