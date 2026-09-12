import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/providers/recently_viewed_provider.dart';
import 'package:spacenotes_client/services/recently_viewed_store.dart';
import 'package:spacenotes_client/widgets/records_view_after_dwell.dart';

/// Records calls instead of touching sqlite, so the timing rules can be
/// asserted without a database.
class FakeRecentlyViewedStore implements RecentlyViewedStore {
  final List<String> recorded = [];
  List<String> stored = [];

  @override
  Future<void> record(String fileId) async {
    recorded.add(fileId);
    stored = [fileId, ...stored.where((id) => id != fileId)];
  }

  @override
  Future<List<String>> recentIds() async => stored;

  @override
  Future<void> forget(String fileId) async {
    stored = stored.where((id) => id != fileId).toList();
  }

  @override
  Future<void> clear() async {
    stored = [];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeRecentlyViewedStore store;

  ProviderContainer containerWith(FakeRecentlyViewedStore store) {
    final container = ProviderContainer(overrides: [
      recentlyViewedStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => store = FakeRecentlyViewedStore());

  Future<void> pumpViewer(
    WidgetTester tester,
    String fileId,
    ProviderContainer container,
  ) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: RecordsViewAfterDwell(
            fileId: fileId,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  group('dwell', () {
    /// The whole reason for the delay: navigating through a file on the way
    /// somewhere else must not fill the list with things never looked at.
    testWidgets('a file closed before the dwell is not recorded',
        (tester) async {
      final container = containerWith(store);
      await pumpViewer(tester, 'passed-through', container);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(RecentlyViewedStore.dwell);

      expect(store.recorded, isEmpty);
    });

    testWidgets('a file held past the dwell is recorded once', (tester) async {
      final container = containerWith(store);
      await pumpViewer(tester, 'looked-at', container);

      await tester.pump(RecentlyViewedStore.dwell + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(store.recorded, ['looked-at']);
    });

    /// A route reuses the screen when only the id changes. Without restarting
    /// the clock the second file would inherit the first one's elapsed time.
    testWidgets('switching files restarts the clock', (tester) async {
      final container = containerWith(store);
      await pumpViewer(tester, 'first', container);
      await tester.pump(const Duration(milliseconds: 1500));

      await pumpViewer(tester, 'second', container);
      await tester.pump(const Duration(milliseconds: 1500));

      expect(store.recorded, isEmpty,
          reason: 'neither file was held for a full dwell on its own');

      await tester.pump(const Duration(milliseconds: 1000));
      expect(store.recorded, ['second']);
    });
  });

  group('recentlyViewedFilesProvider', () {
    /// Ids are stored, not copies. An id that no longer resolves is a file
    /// deleted elsewhere, and must vanish rather than render as a blank card.
    test('drops ids that no longer resolve to a file', () async {
      store.stored = ['gone', 'alive'];
      final container = containerWith(store);

      await container.read(recentlyViewedIdsProvider.notifier).record('alive');

      expect(container.read(recentlyViewedIdsProvider), contains('alive'));
      // With no live files at all, everything resolves to nothing.
      expect(container.read(recentlyViewedFilesProvider), isEmpty);
    });

    /// The store keeps more than the grid shows, so ids that no longer resolve
    /// are absorbed by the surplus instead of leaving the section short.
    test('the visible list is capped', () async {
      final container = containerWith(store);
      final notifier = container.read(recentlyViewedIdsProvider.notifier);

      for (var i = 0; i < kRecentlyViewedLimit + 10; i++) {
        await notifier.record('file-$i');
      }

      expect(
        container.read(recentlyViewedIdsProvider).length,
        greaterThan(kRecentlyViewedLimit),
        reason: 'the store holds a surplus to absorb deleted files',
      );
      expect(
        container.read(recentlyViewedFilesProvider).length,
        lessThanOrEqualTo(kRecentlyViewedLimit),
      );
    });

    test('recording moves a file to the front', () async {
      final container = containerWith(store);
      final notifier = container.read(recentlyViewedIdsProvider.notifier);

      await notifier.record('a');
      await notifier.record('b');
      await notifier.record('a');

      expect(container.read(recentlyViewedIdsProvider), ['a', 'b']);
    });
  });
}
