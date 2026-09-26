import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v1 schema, verbatim, as it shipped.
Future<void> createV1(Database db) async {
  await db.execute('''
    CREATE TABLE downloads (
      path TEXT PRIMARY KEY,
      local_path TEXT NOT NULL,
      size INTEGER NOT NULL,
      hash TEXT,
      state TEXT NOT NULL
    )
  ''');
}

Future<void> createUploads(Database db) async {
  await db.execute('''
    CREATE TABLE uploads (
      remote_path TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      source_path TEXT NOT NULL,
      size INTEGER NOT NULL,
      sent INTEGER NOT NULL,
      started_ms INTEGER NOT NULL
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// The upgrade runs against every existing install, and `downloads` is the
  /// record of which offloaded files are already on disk. Losing it silently
  /// re-downloads everything, so this asserts the rows survive.
  /// A real file on disk, not [inMemoryDatabasePath]: an in-memory database
  /// is discarded on close, so reopening it creates an empty one and the
  /// upgrade path never actually runs.
  test('upgrading from v1 keeps existing download rows', () async {
    final dir = await Directory.systemTemp.createTemp('migration-test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'spacenotes_downloads.db');

    var db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => createV1(db),
        singleInstance: false,
      ),
    );

    await db.insert('downloads', {
      'path': 'Music/keeper.wav',
      'local_path': '/tmp/keeper.wav',
      'size': 4096,
      'hash': null,
      'state': 'complete',
    });
    await db.close();

    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await createV1(db);
          await createUploads(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await createUploads(db);
        },
        singleInstance: false,
      ),
    );

    final rows = await db.query('downloads');
    expect(rows, hasLength(1));
    expect(rows.first['path'], 'Music/keeper.wav');
    expect(rows.first['state'], 'complete');

    final uploads = await db.query('uploads');
    expect(uploads, isEmpty, reason: 'the new table starts empty');

    await db.close();
  });

  test('a fresh install gets both tables', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await createV1(db);
          await createUploads(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await createUploads(db);
        },
        singleInstance: false,
      ),
    );

    await db.insert('uploads', {
      'remote_path': 'Music/a.wav',
      'session_id': 'abc',
      'source_path': '/tmp/a.wav',
      'size': 100,
      'sent': 20,
      'started_ms': 1,
    });

    expect(await db.query('downloads'), isEmpty);
    expect(await db.query('uploads'), hasLength(1));

    await db.close();
  });

  test('the upgrade is idempotent across a reopen', () async {
    final dir = await Directory.systemTemp.createTemp('migration-idempotent');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'spacenotes_downloads.db');

    var db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => createV1(db),
        singleInstance: false,
      ),
    );
    await db.close();

    for (var i = 0; i < 2; i++) {
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await createV1(db);
            await createUploads(db);
          },
          onUpgrade: (db, from, to) async {
            if (from < 2) await createUploads(db);
          },
          singleInstance: false,
        ),
      );
      expect(await db.query('uploads'), isEmpty);
      await db.close();
    }
  });

  test('upgrading from v2 keeps downloads and uploads and adds an empty queue', () async {
    final dir = await Directory.systemTemp.createTemp('migration-v3');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'spacenotes_downloads.db');

    var db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await createV1(db);
          await createUploads(db);
        },
        singleInstance: false,
      ),
    );
    await db.insert('downloads', {
      'path': 'Masters/keeper.wav',
      'local_path': '/tmp/keeper.wav',
      'size': 4096,
      'hash': null,
      'state': 'complete',
    });
    await db.insert('uploads', {
      'remote_path': 'Music/a.wav',
      'session_id': 'abc',
      'source_path': '/tmp/a.wav',
      'size': 100,
      'sent': 20,
      'started_ms': 1,
    });
    await db.close();

    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await createV1(db);
          await createUploads(db);
          await createDownloadQueue(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await createUploads(db);
          if (from < 3) await createDownloadQueue(db);
        },
        singleInstance: false,
      ),
    );

    expect(await db.query('downloads'), hasLength(1));
    expect(await db.query('uploads'), hasLength(1));
    expect(await db.query('download_queue'), isEmpty);

    await db.close();
  });
}

Future<void> createDownloadQueue(Database db) async {
  await db.execute('''
    CREATE TABLE download_queue (
      path TEXT PRIMARY KEY,
      size INTEGER NOT NULL,
      queued_ms INTEGER NOT NULL
    )
  ''');
}
