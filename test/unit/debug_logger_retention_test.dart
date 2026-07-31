import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:spacenotes_client/services/debug_logger_io.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory logDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('debug_logger_retention');
    logDir = Directory('${tempRoot.path}/logs');
    PathProviderPlatform.instance = _TempPathProvider(tempRoot.path);
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<List<String>> logFileNames() async {
    final entries = await logDir
        .list()
        .where((e) =>
            e is File && e.path.contains('debug_') && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    final names = entries.map((f) => f.path.split('/').last).toList()..sort();
    return names;
  }

  Future<void> fillOneFile(PlatformLogStorage storage) async {
    for (var i = 0; i < 60; i++) {
      storage.writeLine('x' * 100);
    }
    await storage.flush();
  }

  // Rotation installs the new sink synchronously but prunes in a detached
  // future doing real file IO, so the directory can briefly hold one extra
  // file. Poll until retention settles rather than guessing a delay.
  Future<void> settle() async {
    for (var i = 0; i < 200; i++) {
      if ((await logFileNames()).length <= 10) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('log file count never settled to <= 10');
  }

  test('rotation never leaves more than 10 log files on disk', () async {
    final storage = PlatformLogStorage();
    await storage.initialize();
    addTearDown(storage.close);

    for (var rotation = 0; rotation < 25; rotation++) {
      await fillOneFile(storage);
      await settle();
      final count = (await logFileNames()).length;
      expect(count, lessThanOrEqualTo(10),
          reason: 'retention breached after rotation $rotation');
      expect(count, greaterThan(0));
    }

    expect(await logFileNames(), hasLength(10),
        reason: 'steady state should sit exactly at the retention cap');
  });

  test('pruning deletes the oldest files and keeps the newest', () async {
    final storage = PlatformLogStorage();
    await storage.initialize();
    addTearDown(storage.close);

    final seen = <String>{};
    for (var rotation = 0; rotation < 15; rotation++) {
      await fillOneFile(storage);
      await settle();
      seen.addAll(await logFileNames());
    }

    final remaining = await logFileNames();
    final droppedNewest = seen.toList()..sort();
    final expectedKept = droppedNewest.sublist(droppedNewest.length - 10);

    expect(remaining, equals(expectedKept),
        reason: 'the 10 newest timestamps should survive, oldest pruned');
  });

  test('writes after pruning are still retained in some kept file', () async {
    final storage = PlatformLogStorage();
    await storage.initialize();
    addTearDown(storage.close);

    for (var rotation = 0; rotation < 14; rotation++) {
      await fillOneFile(storage);
    }

    storage.writeLine('SURVIVOR-LINE');
    await storage.flush();
    await settle();

    final files = await storage.getLogFiles();
    expect(files, hasLength(10));
    expect(
      files.any((f) => f.content.contains('SURVIVOR-LINE')),
      isTrue,
      reason: 'pruning must not delete the file holding the newest write',
    );
  });

  test('the current log file is never the one deleted by pruning', () async {
    final storage = PlatformLogStorage();
    await storage.initialize();
    addTearDown(storage.close);

    for (var rotation = 0; rotation < 14; rotation++) {
      await fillOneFile(storage);
      final content = await storage.getCurrentLogContent();
      expect(content, isNotNull,
          reason: 'the current log file must still exist after pruning');
    }
  });

  test('clearLogs leaves exactly one fresh log file', () async {
    final storage = PlatformLogStorage();
    await storage.initialize();
    addTearDown(storage.close);

    for (var rotation = 0; rotation < 12; rotation++) {
      await fillOneFile(storage);
    }

    await storage.clearLogs();

    expect(await logFileNames(), hasLength(1));
  });
}
