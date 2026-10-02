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
    state =
        state == FileSortMode.name ? FileSortMode.modified : FileSortMode.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.name);
  }
}

final fileSortModeProvider =
    StateNotifierProvider<FileSortNotifier, FileSortMode>(
  (ref) => FileSortNotifier(),
);

List<SpaceFile> sortFiles(List<SpaceFile> files, FileSortMode mode) {
  switch (mode) {
    case FileSortMode.name:
      return _groupedByBaseName(files);
    case FileSortMode.modified:
      final sorted = files.toList();
      sorted.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      return sorted;
  }
}

final _trailingNumber = RegExp(r'\s+\d+$');

/// Strips repeated trailing " <digits>" tokens (render/date suffixes like
/// "2309" or "2509 2") so re-renders of the same file share one key.
String _baseName(String name) {
  var stripped = name;
  while (true) {
    final match = _trailingNumber.firstMatch(stripped);
    if (match == null) return stripped;
    stripped = stripped.substring(0, match.start);
  }
}

/// Groups files by base name (A→Z), newest render first within each group,
/// so re-renders of one file stay together instead of interleaving with
/// unrelated files by raw filename.
List<SpaceFile> _groupedByBaseName(List<SpaceFile> files) {
  final groups = <String, List<SpaceFile>>{};
  for (final file in files) {
    groups.putIfAbsent(_baseName(file.name).toLowerCase(), () => []).add(file);
  }
  final baseNames = groups.keys.toList()..sort();
  final result = <SpaceFile>[];
  for (final base in baseNames) {
    final group = groups[base]!
      ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    result.addAll(group);
  }
  return result;
}
