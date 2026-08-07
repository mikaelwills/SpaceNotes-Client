import 'package:flutter/foundation.dart';

import 'debug_logger_io.dart'
    if (dart.library.js_interop) 'debug_logger_web.dart' as platform;

export 'debug_logger_io.dart'
    if (dart.library.js_interop) 'debug_logger_web.dart' show LogFileData;

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  platform.PlatformLogStorage? _storage;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() async {
    _initFuture ??= _init();
    await _initFuture;
  }

  void log(String level, String category, String msg, [String? details]) {
    final line = details != null
        ? '${_time()} [$level][$category] $msg | $details'
        : '${_time()} [$level][$category] $msg';
    _storage?.writeLine(line);
    if (kDebugMode) debugPrint(line);
  }

  void debug(String category, String msg, [String? details]) =>
      log('D', category, msg, details);
  void info(String category, String msg, [String? details]) =>
      log('I', category, msg, details);
  void warning(String category, String msg, [String? details]) =>
      log('W', category, msg, details);
  void error(String category, String msg, [String? details]) =>
      log('E', category, msg, details);

  void sync(String msg, [String? details]) => info('SYNC', msg, details);
  void save(String msg, [String? details]) => info('SAVE', msg, details);
  void connection(String msg, [String? details]) => info('CONN', msg, details);
  void editor(String msg, [String? details]) => debug('EDITOR', msg, details);
  void transaction(String msg, [String? details]) => info('TXN', msg, details);

  void chat(String msg, [String? details]) => info('CHAT', msg, details);
  void chatDebug(String msg, [String? details]) => debug('CHAT', msg, details);
  void chatError(String msg, [String? details]) => error('CHAT', msg, details);
  void sse(String msg, [String? details]) => info('SSE', msg, details);
  void sseDebug(String msg, [String? details]) => debug('SSE', msg, details);
  void sseError(String msg, [String? details]) => error('SSE', msg, details);
  void queue(String msg, [String? details]) => info('QUEUE', msg, details);

  LogSpan span(String category, String name) => LogSpan._(this, category, name);

  Future<List<platform.LogFileData>> getLogFiles() async {
    if (_storage == null) return [];
    return await _storage!.getLogFiles();
  }

  Future<void> exportToFile() async {
    await _storage?.exportLogs();
  }

  Future<String?> getLogs() async {
    return await _storage?.getCurrentLogContent();
  }

  Future<void> clearLogs() async {
    await _storage?.clearLogs();
  }

  Future<void> close() async {
    await _storage?.close();
  }

  bool get isAvailable => _storage?.isAvailable ?? false;

  Future<void> _init() async {
    try {
      _storage = platform.createPlatformStorage();
      await _storage!.initialize();
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
}

class LogSpan {
  final DebugLogger _logger;
  final String category;
  final String name;
  final Stopwatch _watch = Stopwatch()..start();
  bool _sawPause = false;

  LogSpan._(this._logger, this.category, this.name) {
    _logger.log('I', category, '$name: span start');
  }

  void pause() {
    if (!_watch.isRunning) return;
    _watch.stop();
    _sawPause = true;
  }

  void resume() {
    if (_watch.isRunning) return;
    _watch.start();
  }

  void lap(String label) {
    _logger.log(
        'I', category, '$name: $label +${_watch.elapsedMilliseconds}ms');
  }

  void end([String? details]) {
    _watch.stop();
    final aborted = details != null && details.startsWith('aborted');
    final suffix = _sawPause ? ' (excludes background time)' : '';
    final measure = aborted
        ? 'abandoned after ${_watch.elapsedMilliseconds}ms$suffix'
        : 'complete ${_watch.elapsedMilliseconds}ms$suffix';
    _logger.log('I', category, '$name: $measure', details);
  }
}

final debugLogger = DebugLogger();
