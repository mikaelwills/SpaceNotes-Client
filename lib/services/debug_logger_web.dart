import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PlatformLogStorage {
  final List<_LogSession> _sessions = [];
  _LogSession? _currentSession;
  int _charCount = 0;

  static const int _maxChars = 5000;

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}_'
        '${dt.hour.toString().padLeft(2, '0')}-${dt.minute.toString().padLeft(2, '0')}-${dt.second.toString().padLeft(2, '0')}-'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  Future<void> initialize() async {
    await startNewLogFile();
  }

  Future<void> startNewLogFile() async {
    final timestamp = _formatTimestamp(DateTime.now());
    final header = '=== SESSION: ${DateTime.now().toIso8601String()} ===\n';

    _currentSession = _LogSession(timestamp: timestamp, lines: [header]);
    _sessions.add(_currentSession!);
    _charCount = header.length;

    if (_sessions.length > 10) {
      _sessions.removeAt(0);
    }
  }

  void writeLine(String line) {
    _currentSession?.lines.add(line);
    _charCount += line.length + 1;
    _rotateIfNeeded();
  }

  void _rotateIfNeeded() {
    if (_charCount >= _maxChars && _currentSession != null) {
      final timestamp = _formatTimestamp(DateTime.now());
      final header = '=== SESSION (continued): ${DateTime.now().toIso8601String()} ===\n';

      _currentSession = _LogSession(timestamp: timestamp, lines: [header]);
      _sessions.add(_currentSession!);
      _charCount = header.length;

      if (_sessions.length > 10) {
        _sessions.removeAt(0);
      }
    }
  }

  Future<void> flush() async {}

  Future<void> close() async {}

  Future<List<LogFileData>> getLogFiles() async {
    return _sessions.map((s) => LogFileData(
      path: 'debug_${s.timestamp}.log',
      timestamp: s.timestamp,
      content: s.lines.join('\n'),
    )).toList();
  }

  Future<String?> getCurrentLogContent() async {
    if (_currentSession == null) return null;
    return _currentSession!.lines.join('\n');
  }

  Future<void> clearLogs() async {
    _sessions.clear();
    await startNewLogFile();
    _currentSession?.lines.add('=== LOG CLEARED: ${DateTime.now().toIso8601String()} ===\n');
  }

  Future<void> exportLogs() async {
    final allContent = _sessions.map((s) => s.lines.join('\n')).join('\n\n');

    final bytes = Uint8List.fromList(utf8.encode(allContent));
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain'),
    );

    final url = web.URL.createObjectURL(blob);
    final timestamp = _formatTimestamp(DateTime.now());

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = 'spacenotes_debug_$timestamp.log';
    anchor.click();

    web.URL.revokeObjectURL(url);
  }

  bool get isAvailable => true;
}

class _LogSession {
  final String timestamp;
  final List<String> lines;

  _LogSession({required this.timestamp, required this.lines});
}

class LogFileData {
  final String path;
  final String timestamp;
  final String content;

  LogFileData({required this.path, required this.timestamp, required this.content});
}

PlatformLogStorage createPlatformStorage() => PlatformLogStorage();
