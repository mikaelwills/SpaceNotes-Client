import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PlatformLogStorage {
  Directory? _logDir;
  File? _currentLogFile;
  IOSink? _sink;
  int _charCount = 0;
  String? _currentTimestamp;
  bool _isRotating = false;

  static const int _maxChars = 5000;

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}_'
        '${dt.hour.toString().padLeft(2, '0')}-${dt.minute.toString().padLeft(2, '0')}-${dt.second.toString().padLeft(2, '0')}-'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _logDir = Directory('${appDir.path}/logs');
    if (!await _logDir!.exists()) {
      await _logDir!.create(recursive: true);
    }
    await startNewLogFile();
  }

  Future<void> startNewLogFile() async {
    await _sink?.flush();
    await _sink?.close();

    _currentTimestamp = _formatTimestamp(DateTime.now());
    _currentLogFile = File('${_logDir!.path}/debug_$_currentTimestamp.log');
    _sink = _currentLogFile!.openWrite(mode: FileMode.append);
    final header = '=== SESSION: ${DateTime.now().toIso8601String()} ===\n';
    _sink!.writeln(header);
    _charCount = header.length;
  }

  void writeLine(String line) {
    _sink?.writeln(line);
    _charCount += line.length + 1;
    _rotateIfNeeded();
  }

  void _rotateIfNeeded() {
    if (_charCount >= _maxChars && !_isRotating && _logDir != null) {
      _isRotating = true;

      final oldSink = _sink;

      _currentTimestamp = _formatTimestamp(DateTime.now());
      _currentLogFile = File('${_logDir!.path}/debug_$_currentTimestamp.log');
      _sink = _currentLogFile!.openWrite(mode: FileMode.append);
      final header = '=== SESSION (continued): ${DateTime.now().toIso8601String()} ===\n';
      _sink!.writeln(header);
      _charCount = header.length;

      unawaited(Future(() async {
        await oldSink?.flush();
        await oldSink?.close();
        _isRotating = false;
      }));
    }
  }

  Future<void> flush() async {
    await _sink?.flush();
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  Future<List<LogFileData>> getLogFiles() async {
    if (_logDir == null) return [];

    await _sink?.flush();

    final files = await _logDir!
        .list()
        .where((e) => e is File && e.path.contains('debug_') && e.path.endsWith('.log'))
        .cast<File>()
        .toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    final results = <LogFileData>[];
    for (final file in files) {
      final filename = file.path.split('/').last;
      final timestamp = filename.replaceAll('debug_', '').replaceAll('.log', '');
      final content = await file.readAsString();
      results.add(LogFileData(path: file.path, timestamp: timestamp, content: content));
    }
    return results;
  }

  Future<String?> getCurrentLogContent() async {
    if (_currentLogFile == null) return null;
    await _sink?.flush();
    if (await _currentLogFile!.exists()) {
      return await _currentLogFile!.readAsString();
    }
    return null;
  }

  Future<void> clearLogs() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    if (_logDir != null && await _logDir!.exists()) {
      final files = await _logDir!.list().toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    }

    await startNewLogFile();
    _sink!.writeln('=== LOG CLEARED: ${DateTime.now().toIso8601String()} ===\n');
  }

  Future<void> exportLogs() async {
    if (_currentLogFile == null) return;

    await _sink?.flush();

    final logFiles = await getLogFiles();
    if (logFiles.isEmpty) return;

    final files = logFiles.map((l) => XFile(l.path)).toList();

    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'SpaceNotes Debug Logs',
      ),
    );
  }

  bool get isAvailable => true;
}

class LogFileData {
  final String path;
  final String timestamp;
  final String content;

  LogFileData({required this.path, required this.timestamp, required this.content});
}

PlatformLogStorage createPlatformStorage() => PlatformLogStorage();
