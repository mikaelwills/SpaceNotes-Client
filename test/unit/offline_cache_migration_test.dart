import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';

void main() {
  late Directory appDir;
  late SpacetimeDbNotesRepository repo;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('lane_cache_test');
    repo = SpacetimeDbNotesRepository();
  });

  tearDown(() async {
    if (await appDir.exists()) {
      await appDir.delete(recursive: true);
    }
  });

  Future<void> seed(String name, {String content = 'x'}) async {
    final dir = Directory('${appDir.path}/$name');
    await dir.create(recursive: true);
    await File('${dir.path}/table_space_file.json').writeAsString(content);
  }

  Future<bool> exists(String name) =>
      Directory('${appDir.path}/$name').exists();

  test('the pre-lane cache is adopted as the notes lane cache', () async {
    await seed('spacenotes_offline', content: 'legacy-rows');

    await repo.migrateOfflineCachesForTest(appDir.path);

    expect(await exists('spacenotes_offline'), isFalse);
    expect(await exists('spacenotes_offline_notes'), isTrue);
    final adopted = File(
        '${appDir.path}/spacenotes_offline_notes/table_space_file.json');
    expect(await adopted.readAsString(), 'legacy-rows');
  });

  test('adoption runs whichever lane initialises first', () async {
    await seed('spacenotes_offline', content: 'legacy-rows');

    await repo.migrateOfflineCachesForTest(appDir.path);
    await repo.migrateOfflineCachesForTest(appDir.path);

    expect(await exists('spacenotes_offline_notes'), isTrue);
    final adopted = File(
        '${appDir.path}/spacenotes_offline_notes/table_space_file.json');
    expect(await adopted.readAsString(), 'legacy-rows');
  });

  test('a superseded pre-lane cache is removed rather than left behind',
      () async {
    await seed('spacenotes_offline', content: 'stale');
    await seed('spacenotes_offline_notes', content: 'current');

    await repo.migrateOfflineCachesForTest(appDir.path);

    expect(await exists('spacenotes_offline'), isFalse);
    final kept = File(
        '${appDir.path}/spacenotes_offline_notes/table_space_file.json');
    expect(await kept.readAsString(), 'current');
  });

  test('a cache no lane claims is swept', () async {
    await seed('spacenotes_offline_retired');
    await seed('spacenotes_offline_notes');
    await seed('spacenotes_offline_chat');

    await repo.migrateOfflineCachesForTest(appDir.path);

    expect(await exists('spacenotes_offline_retired'), isFalse);
    expect(await exists('spacenotes_offline_notes'), isTrue);
    expect(await exists('spacenotes_offline_chat'), isTrue);
  });

  test('unrelated directories are never touched', () async {
    final other = Directory('${appDir.path}/some_other_app_data');
    await other.create(recursive: true);
    await seed('spacenotes_offline_notes');

    await repo.migrateOfflineCachesForTest(appDir.path);

    expect(await other.exists(), isTrue);
  });
}
