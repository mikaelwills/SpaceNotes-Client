import 'exit_recorder_io.dart'
    if (dart.library.js_interop) 'exit_recorder_web.dart' as platform;

final exitRecorder = platform.PlatformExitRecorder();
