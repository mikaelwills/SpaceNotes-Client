import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'debug_logger.dart';

class PlatformExitRecorder {
  File? _file;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/last_session_state.json');
    debugLogger.info('APP', 'Previous session end', _attributePreviousExit());
    record('launched');
  }

  String _attributePreviousExit() {
    if (_file == null || !_file!.existsSync()) {
      return 'no sentinel - first launch';
    }
    try {
      final m = jsonDecode(_file!.readAsStringSync()) as Map<String, dynamic>;
      final state = m['state'];
      final ts = m['ts'];
      switch (state) {
        case 'detached':
          return 'USER KILL - terminate callback (detached) received, last seen $ts';
        case 'paused':
        case 'hidden':
          return 'KILLED WHILE SUSPENDED after $ts - user swipe-kill or iOS jettison, no callback distinguishes them';
        default:
          return 'DIED IN FOREGROUND - last state=$state at $ts, crash or instant kill';
      }
    } on Exception catch (e) {
      return 'sentinel unreadable: $e';
    }
  }

  void record(String state) {
    try {
      _file?.writeAsStringSync(
        jsonEncode({'state': state, 'ts': DateTime.now().toIso8601String()}),
        flush: true,
      );
    } on Exception {
      return;
    }
  }
}
