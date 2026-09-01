import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

enum DownloadState { notDownloaded, partial, complete }

class LocalDownloadStore {
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'spacenotes_downloads.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            path TEXT PRIMARY KEY,
            local_path TEXT NOT NULL,
            size INTEGER NOT NULL,
            hash TEXT,
            state TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<DownloadState> stateFor(String remotePath) async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'path = ?',
      whereArgs: [remotePath],
      limit: 1,
    );
    if (rows.isEmpty) return DownloadState.notDownloaded;

    final row = rows.first;
    final localPath = row['local_path'] as String;
    final file = File(localPath);
    if (!await file.exists()) {
      await db.delete('downloads', where: 'path = ?', whereArgs: [remotePath]);
      return DownloadState.notDownloaded;
    }

    return DownloadState.values.byName(row['state'] as String);
  }

  Future<String> localPathFor(String remotePath) async {
    final dir = await getApplicationSupportDirectory();
    final downloadsDir = Directory(p.join(dir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    final safeName = remotePath.replaceAll('/', '_');
    return p.join(downloadsDir.path, safeName);
  }

  Future<void> markPartial(String remotePath, String localPath, int size) async {
    final db = await _database();
    await db.insert(
      'downloads',
      {
        'path': remotePath,
        'local_path': localPath,
        'size': size,
        'hash': null,
        'state': DownloadState.partial.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> markCompleteIfVerified(
    String remotePath,
    String localPath,
    int expectedSize,
  ) async {
    final file = File(localPath);
    if (!await file.exists()) return false;
    final actualSize = await file.length();
    if (actualSize != expectedSize) return false;

    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    final db = await _database();
    await db.insert(
      'downloads',
      {
        'path': remotePath,
        'local_path': localPath,
        'size': actualSize,
        'hash': hash,
        'state': DownloadState.complete.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<void> remove(String remotePath) async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'path = ?',
      whereArgs: [remotePath],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final file = File(rows.first['local_path'] as String);
      if (await file.exists()) await file.delete();
    }
    await db.delete('downloads', where: 'path = ?', whereArgs: [remotePath]);
  }

  /// Total bytes currently held on this device, complete downloads only.
  Future<int> totalSize() async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'state = ?',
      whereArgs: [DownloadState.complete.name],
    );
    var total = 0;
    for (final row in rows) {
      total += row['size'] as int;
    }
    return total;
  }

  Future<int> downloadedCount() async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'state = ?',
      whereArgs: [DownloadState.complete.name],
    );
    return rows.length;
  }

  /// Deletes every local file this store knows about — the STDB row and
  /// vault file are untouched, this only frees on-device storage. Tapping a
  /// file afterward re-downloads it, same as if it had never been fetched.
  Future<void> offloadAll() async {
    final db = await _database();
    final rows = await db.query('downloads');
    for (final row in rows) {
      final file = File(row['local_path'] as String);
      if (await file.exists()) await file.delete();
    }
    await db.delete('downloads');
  }
}
