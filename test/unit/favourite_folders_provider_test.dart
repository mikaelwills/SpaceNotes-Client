import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacenotes_client/providers/favourite_folders_provider.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('favouriteFoldersProvider persistence', () {
    test('add then reload survives a fresh provider instance', () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      container1.read(favouriteFoldersProvider.notifier).add('Projects');
      container1.read(favouriteFoldersProvider.notifier).add('Journal');
      await _settle();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(favouriteFoldersProvider);
      await _settle();

      expect(
        container2.read(favouriteFoldersProvider),
        ['Projects', 'Journal'],
      );
    });

    test('no limit on favourited-folder count: 25 paths all retained and reload',
        () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      final notifier = container1.read(favouriteFoldersProvider.notifier);
      for (var i = 0; i < 25; i++) {
        notifier.add('Folder$i');
      }
      await _settle();

      expect(container1.read(favouriteFoldersProvider).length, 25);

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(favouriteFoldersProvider);
      await _settle();

      expect(container2.read(favouriteFoldersProvider).length, 25);
    });

    test('reorder produces expected order and persists through reload',
        () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      final notifier = container1.read(favouriteFoldersProvider.notifier);
      notifier.add('a');
      notifier.add('b');
      notifier.add('c');
      await _settle();

      notifier.reorder(0, 2);
      await _settle();
      expect(container1.read(favouriteFoldersProvider), ['b', 'c', 'a']);

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(favouriteFoldersProvider);
      await _settle();
      expect(container2.read(favouriteFoldersProvider), ['b', 'c', 'a']);
    });

    test('remove drops exactly the requested path', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(favouriteFoldersProvider.notifier);
      notifier.add('a');
      notifier.add('b');
      await _settle();

      notifier.remove('a');
      await _settle();

      expect(container.read(favouriteFoldersProvider), ['b']);
    });

    test('syncWithExistingPaths silently drops a favourite whose folder is gone',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(favouriteFoldersProvider.notifier);
      notifier.add('a');
      notifier.add('b');
      await _settle();

      notifier.syncWithExistingPaths({'b'});

      expect(container.read(favouriteFoldersProvider), ['b']);
    });

    test(
        'syncWithExistingPaths with empty set leaves state unchanged and not persisted',
        () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      final notifier1 = container1.read(favouriteFoldersProvider.notifier);
      notifier1.add('A');
      notifier1.add('B');
      await _settle();

      notifier1.syncWithExistingPaths({});

      expect(container1.read(favouriteFoldersProvider), ['A', 'B']);

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(favouriteFoldersProvider);
      await _settle();

      expect(container2.read(favouriteFoldersProvider), ['A', 'B']);
    });

    test('syncWithExistingPaths with single path drops others', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(favouriteFoldersProvider.notifier);
      notifier.add('A');
      notifier.add('B');
      await _settle();

      notifier.syncWithExistingPaths({'A'});

      expect(container.read(favouriteFoldersProvider), ['A']);
    });
  });
}
