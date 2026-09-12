import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/space_file.dart';
import '../services/recently_viewed_store.dart';
import 'notes_providers.dart';

final recentlyViewedStoreProvider = Provider<RecentlyViewedStore>(
  (ref) => RecentlyViewedStore(),
);

/// Ids this device has viewed, newest first.
///
/// A [StateNotifier] rather than a [FutureProvider] because it is written to as
/// well as read: recording a view has to push a new value to everything
/// watching, which a plain future cannot do.
class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier(this._store) : super(const []) {
    _load();
  }

  final RecentlyViewedStore _store;

  Future<void> _load() async {
    final ids = await _store.recentIds();
    if (mounted) state = ids;
  }

  /// Moves [fileId] to the front. Updates state from the store rather than
  /// guessing, so the in-memory list and the table cannot drift.
  Future<void> record(String fileId) async {
    await _store.record(fileId);
    await _load();
  }

  Future<void> clear() async {
    await _store.clear();
    if (mounted) state = const [];
  }
}

final recentlyViewedIdsProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<String>>(
  (ref) => RecentlyViewedNotifier(ref.watch(recentlyViewedStoreProvider)),
);

/// How many viewed files the grid shows.
///
/// Applied after dropping ids that no longer resolve, so deleted files do not
/// eat into the count and leave the section short.
const int kRecentlyViewedLimit = 20;

/// Viewed files that still exist, newest first.
///
/// Resolves ids against live rows, so a renamed file follows automatically and
/// a deleted one drops out without needing a cleanup pass.
final recentlyViewedFilesProvider = Provider<List<SpaceFile>>((ref) {
  final ids = ref.watch(recentlyViewedIdsProvider);
  if (ids.isEmpty) return const [];

  final byId = {for (final f in ref.watch(fileListProvider)) f.id: f};

  return ids
      .map((id) => byId[id])
      .whereType<SpaceFile>()
      .take(kRecentlyViewedLimit)
      .toList();
});
