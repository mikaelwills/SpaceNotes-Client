import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal() {
    _init();
  }

  File? _logFile;
  IOSink? _sink;

  Future<void> _init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/spacenotes_debug.log');
      _sink = _logFile!.openWrite(mode: FileMode.append);
      _sink!.writeln('\n=== SESSION: ${DateTime.now().toIso8601String()} ===\n');
    } catch (e) {
      debugPrint('Failed to initialize debug logger: $e');
    }
  }

  String _time() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  void log(String level, String category, String msg, [String? details]) {
    final line = details != null
        ? '${_time()} [$level][$category] $msg | $details'
        : '${_time()} [$level][$category] $msg';
    _sink?.writeln(line);
    if (kDebugMode) debugPrint(line);
  }

  void debug(String category, String msg, [String? details]) => log('D', category, msg, details);
  void info(String category, String msg, [String? details]) => log('I', category, msg, details);
  void warning(String category, String msg, [String? details]) => log('W', category, msg, details);
  void error(String category, String msg, [String? details]) => log('E', category, msg, details);

  void sync(String msg, [String? details]) => info('SYNC', msg, details);
  void save(String msg, [String? details]) => info('SAVE', msg, details);
  void connection(String msg, [String? details]) => info('CONN', msg, details);
  void editor(String msg, [String? details]) => debug('EDITOR', msg, details);
  void transaction(String msg, [String? details]) => info('TXN', msg, details);

  Future<void> exportToFile() async {
    if (_logFile == null) return;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final path = _logFile!.path;

    if (await _logFile!.exists()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'SpaceNotes Debug Log',
        ),
      );
    }

    _sink = _logFile!.openWrite(mode: FileMode.append);
  }

  Future<String?> getLogs() async {
    if (_logFile == null) return null;
    await _sink?.flush();
    if (await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return null;
  }

  Future<void> clearLogs() async {
    if (_logFile == null) return;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final path = _logFile!.path;
    if (await _logFile!.exists()) {
      await _logFile!.delete();
    }

    _logFile = File(path);
    _sink = _logFile!.openWrite(mode: FileMode.append);
    _sink!.writeln('=== LOG CLEARED: ${DateTime.now().toIso8601String()} ===\n');
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}

final debugLogger = DebugLogger();
