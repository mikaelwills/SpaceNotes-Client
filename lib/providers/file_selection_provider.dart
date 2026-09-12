import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which files are ticked, and whether the grid is in select mode at all.
///
/// Select mode is explicit rather than implied by a non-empty selection: the
/// user turns it on before tapping, so a tap is unambiguous — open the file,
/// or tick it — with no long-press to discover.
class FileSelectionState {
  const FileSelectionState({
    this.active = false,
    this.selectedIds = const {},
  });

  final bool active;
  final Set<String> selectedIds;

  int get count => selectedIds.length;
  bool get hasSelection => selectedIds.isNotEmpty;

  bool isSelected(String id) => selectedIds.contains(id);

  FileSelectionState copyWith({bool? active, Set<String>? selectedIds}) {
    return FileSelectionState(
      active: active ?? this.active,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class FileSelectionNotifier extends StateNotifier<FileSelectionState> {
  FileSelectionNotifier() : super(const FileSelectionState());

  /// Leaving select mode always clears the ticks, so re-entering never starts
  /// with a stale selection the user has forgotten about.
  void toggleMode() {
    state = state.active
        ? const FileSelectionState()
        : const FileSelectionState(active: true);
  }

  void exit() => state = const FileSelectionState();

  void toggle(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: ids.toSet());
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: const {});
  }
}

final fileSelectionProvider =
    StateNotifierProvider<FileSelectionNotifier, FileSelectionState>(
  (ref) => FileSelectionNotifier(),
);
