import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

enum DownloadState { notDownloaded, partial, complete }

/// An upload that outlived the process that started it.
class ResumableUploadRow {
  const ResumableUploadRow({
    required this.remotePath,
    required this.sessionId,
    required this.sourcePath,
    required this.size,
    required this.sent,
  });

  final String remotePath;
  final String sessionId;
  final String sourcePath;
  final int size;

  /// Last offset this device recorded. The server is the authority, so a
  /// resume asks it rather than trusting this — it is for showing progress
  /// before the first request goes out.
  final int sent;

  String get fileName => remotePath.split('/').last;
}

class QueuedDownload {
  const QueuedDownload({required this.path, required this.size});

  final String path;
  final int size;
}

abstract interface class DownloadQueueStore {
  Future<void> enqueueDownloads(List<QueuedDownload> items);
  Future<List<QueuedDownload>> queuedDownloads();
  Future<void> dequeueDownload(String path);
  Future<void> clearDownloadQueue();
}

class LocalDownloadStore implements DownloadQueueStore {
  Database? _db;

  Future<DownloadState> stateFor(String remotePath, {int? expectedSize}) async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'path = ?',
      whereArgs: [remotePath],
      limit: 1,
    );
    if (rows.isEmpty) return DownloadState.notDownloaded;

    final row = rows.first;
    final localPath = row['local_path'];
    if (localPath is! String) return DownloadState.notDownloaded;
    final file = File(localPath);
    if (!await file.exists()) {
      await db.delete('downloads', where: 'path = ?', whereArgs: [remotePath]);
      return DownloadState.notDownloaded;
    }

    final state = row['state'];
    if (state is! String) return DownloadState.notDownloaded;
    final parsed = DownloadState.values.byName(state);
    if (parsed == DownloadState.complete &&
        expectedSize != null &&
        row['size'] != expectedSize) {
      await file.delete();
      await db.delete('downloads', where: 'path = ?', whereArgs: [remotePath]);
      return DownloadState.notDownloaded;
    }
    return parsed;
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

  /// Records an in-flight download so an abandoned partial is visible to
  /// [totalSize]/[offloadAll] instead of sitting on disk untracked.
  Future<void> markPartial(
      String remotePath, String localPath, int size) async {
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
      final localPath = rows.first['local_path'];
      if (localPath is String) {
        final file = File(localPath);
        if (await file.exists()) await file.delete();
        final peaks = File('$localPath.peaks.json');
        if (await peaks.exists()) await peaks.delete();
      }
    }
    await db.delete('downloads', where: 'path = ?', whereArgs: [remotePath]);
  }

  /// Deletes just this one local file — the STDB row and vault copy are
  /// untouched, this only frees on-device storage. Tapping the file
  /// afterward re-downloads it, same as if it had never been fetched.
  Future<void> offload(String remotePath) => remove(remotePath);

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
      final size = row['size'];
      if (size is int) total += size;
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
      final localPath = row['local_path'];
      if (localPath is! String) continue;
      final file = File(localPath);
      if (await file.exists()) await file.delete();
      final peaks = File('$localPath.peaks.json');
      if (await peaks.exists()) await peaks.delete();
    }
    await db.delete('downloads');
  }

  /// Deletes files in the downloads directory that no row points at.
  ///
  /// Partials written before [markPartial] had any callers left untracked
  /// bytes behind, and a crash between writing a file and inserting its row
  /// can still do so. Returns the number of bytes reclaimed.
  Future<int> sweepOrphans() async {
    final dir = await getApplicationSupportDirectory();
    final downloadsDir = Directory(p.join(dir.path, 'downloads'));
    if (!await downloadsDir.exists()) return 0;

    final db = await _database();
    final rows = await db.query('downloads', columns: ['local_path']);
    final known = {
      for (final row in rows)
        if (row['local_path'] is String) row['local_path'] as String,
    };

    var reclaimed = 0;
    await for (final entity in downloadsDir.list()) {
      if (entity is! File || known.contains(entity.path)) continue;
      reclaimed += await entity.length();
      await entity.delete();
    }
    return reclaimed;
  }

  /// Records an upload's server session so a relaunch can resume it.
  ///
  /// Written before the first chunk and updated as chunks land, so a process
  /// killed at any point leaves a row pointing at real server-side bytes.
  Future<void> rememberUpload({
    required String remotePath,
    required String sessionId,
    required String sourcePath,
    required int size,
    required int sent,
  }) async {
    final db = await _database();
    await db.insert(
      'uploads',
      {
        'remote_path': remotePath,
        'session_id': sessionId,
        'source_path': sourcePath,
        'size': size,
        'sent': sent,
        'started_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUploadProgress(String remotePath, int sent) async {
    final db = await _database();
    await db.update(
      'uploads',
      {'sent': sent},
      where: 'remote_path = ?',
      whereArgs: [remotePath],
    );
  }

  Future<void> forgetUpload(String remotePath) async {
    final db = await _database();
    await db
        .delete('uploads', where: 'remote_path = ?', whereArgs: [remotePath]);
  }

  /// Uploads that were in flight when the app last stopped.
  ///
  /// A row whose source file has since disappeared is dropped rather than
  /// returned — on iOS a picked file can live in a temp directory the system
  /// clears between launches, and there is nothing left to resume from.
  Future<List<ResumableUploadRow>> pendingUploads() async {
    final db = await _database();
    final rows = await db.query('uploads');

    final pending = <ResumableUploadRow>[];
    for (final row in rows) {
      final sourcePath = row['source_path'];
      final remotePath = row['remote_path'];
      if (sourcePath is! String || remotePath is! String) continue;

      if (!await File(sourcePath).exists()) {
        await db.delete('uploads',
            where: 'remote_path = ?', whereArgs: [remotePath]);
        continue;
      }

      pending.add(ResumableUploadRow(
        remotePath: remotePath,
        sessionId: row['session_id'] as String,
        sourcePath: sourcePath,
        size: row['size'] as int,
        sent: row['sent'] as int,
      ));
    }
    return pending;
  }

  /// Downloads that were partway through when the app last stopped.
  Future<List<String>> pendingDownloads() async {
    final db = await _database();
    final rows = await db.query(
      'downloads',
      where: 'state = ?',
      whereArgs: [DownloadState.partial.name],
    );
    return rows.map((r) => r['path']).whereType<String>().toList();
  }

  @override
  Future<void> enqueueDownloads(List<QueuedDownload> items) async {
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      batch.insert(
        'download_queue',
        {'path': items[i].path, 'size': items[i].size, 'queued_ms': now + i},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<QueuedDownload>> queuedDownloads() async {
    final db = await _database();
    final rows = await db.query('download_queue', orderBy: 'queued_ms, rowid');
    return [
      for (final r in rows)
        QueuedDownload(path: r['path'] as String, size: r['size'] as int),
    ];
  }

  @override
  Future<void> dequeueDownload(String path) async {
    final db = await _database();
    await db.delete('download_queue', where: 'path = ?', whereArgs: [path]);
  }

  @override
  Future<void> clearDownloadQueue() async {
    final db = await _database();
    await db.delete('download_queue');
  }

  static Future<void> _createDownloadQueue(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS download_queue (
        path TEXT PRIMARY KEY,
        size INTEGER NOT NULL,
        queued_ms INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createDownloads(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        path TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        hash TEXT,
        state TEXT NOT NULL
      )
    ''');
  }

  /// One row per upload that has not finished.
  ///
  /// `session_id` is what makes an upload resumable after the process dies:
  /// the server holds the bytes under that id, and without it a relaunch has
  /// no way to ask what survived.
  static Future<void> _createUploads(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS uploads (
        remote_path TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        source_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        sent INTEGER NOT NULL,
        started_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'spacenotes_downloads.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await _createDownloads(db);
        await _createUploads(db);
        await _createDownloadQueue(db);
      },
      onUpgrade: (db, from, to) async {
        // Additive only. An existing install's `downloads` rows are the
        // record of every offloaded file on disk; dropping or recreating
        // that table would make all of them re-download.
        if (from < 2) await _createUploads(db);
        if (from < 3) await _createDownloadQueue(db);
      },
    );
    return _db!;
  }
}
