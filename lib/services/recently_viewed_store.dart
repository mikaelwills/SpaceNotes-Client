import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/capabilities.dart';
import 'debug_logger.dart';

/// Which files this device has looked at, newest first.
///
/// Deliberately local: "what I was doing on this phone" is not shared truth,
/// and putting it in SpacetimeDB would replicate it to every device and add
/// commitlog writes for something only one device cares about.
///
/// Stores ids only. A stored name or path would go stale the moment a file is
/// renamed elsewhere; resolving ids against live rows means renames follow for
/// free and deleted files simply stop resolving.
class RecentlyViewedStore {
  static const _maxEntries = 30;

  /// How long a file must stay open before it counts as viewed. Without this,
  /// passing through a file on the way to another one would fill the list with
  /// things the user never looked at.
  static const dwell = Duration(seconds: 2);

  Database? _db;

  Future<void> record(String fileId) async {
    if (!Capabilities.hasPersistentCache) return;
    if (fileId.isEmpty) return;

    try {
      final db = await _database();
      await db.insert(
        'viewed_files',
        {
          'file_id': fileId,
          'viewed_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _trim(db);
    } catch (e) {
      // A view record is never worth failing a screen over.
      debugLogger.warning('RECENT', 'Could not record view', '$fileId: $e');
    }
  }

  /// File ids this device has viewed, most recent first.
  Future<List<String>> recentIds() async {
    if (!Capabilities.hasPersistentCache) return const [];

    try {
      final db = await _database();
      final rows = await db.query(
        'viewed_files',
        orderBy: 'viewed_at DESC',
        limit: _maxEntries,
      );
      return rows.map((r) => r['file_id']).whereType<String>().toList();
    } catch (e) {
      debugLogger.warning('RECENT', 'Could not read recent views', e.toString());
      return const [];
    }
  }

  Future<void> forget(String fileId) async {
    if (!Capabilities.hasPersistentCache) return;
    final db = await _database();
    await db.delete('viewed_files', where: 'file_id = ?', whereArgs: [fileId]);
  }

  Future<void> clear() async {
    if (!Capabilities.hasPersistentCache) return;
    final db = await _database();
    await db.delete('viewed_files');
  }

  /// Keeps the table bounded. The list is a convenience, not a history.
  Future<void> _trim(Database db) async {
    await db.rawDelete(
      '''
      DELETE FROM viewed_files
      WHERE file_id NOT IN (
        SELECT file_id FROM viewed_files ORDER BY viewed_at DESC LIMIT ?
      )
      ''',
      [_maxEntries],
    );
  }

  /// Its own database file, separate from the download/upload store.
  ///
  /// That store's tables describe bytes on disk; losing this one costs a
  /// convenience list, so they should not share a migration path where a
  /// mistake in one can take out the other.
  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'spacenotes_recent.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE viewed_files (
            file_id TEXT PRIMARY KEY,
            viewed_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX viewed_files_by_time ON viewed_files (viewed_at DESC)',
        );
      },
    );
    return _db!;
  }
}
