import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../generated/space_file.dart';

enum FileSortMode { name, modified }

class FileSortNotifier extends StateNotifier<FileSortMode> {
  FileSortNotifier() : super(FileSortMode.name) {
    _load();
  }

  static const _prefsKey = 'file_sort_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == FileSortMode.modified.name) state = FileSortMode.modified;
  }

  Future<void> toggle() async {
    state = state == FileSortMode.name
        ? FileSortMode.modified
        : FileSortMode.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.name);
  }
}

final fileSortModeProvider =
    StateNotifierProvider<FileSortNotifier, FileSortMode>(
  (ref) => FileSortNotifier(),
);

List<SpaceFile> sortFiles(List<SpaceFile> files, FileSortMode mode) {
  final sorted = files.toList();
  switch (mode) {
    case FileSortMode.name:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case FileSortMode.modified:
      sorted.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
  }
  return sorted;
}
