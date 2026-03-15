import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'video_capture.dart';

class WebVideoCaptureService implements VideoCaptureService {
  final _frameController = StreamController<Uint8List>.broadcast();
  bool _isCapturing = false;
  Timer? _captureTimer;
  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  FrameTimingCallback? _onFrameTiming;

  @override
  Stream<Uint8List> get frameStream => _frameController.stream;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> start({int fps = 10, int width = 320, int height = 240, FrameTimingCallback? onFrameTiming}) async {
    _onFrameTiming = onFrameTiming;
    _video = web.HTMLVideoElement();
    _canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;

    final constraints = web.MediaStreamConstraints(
      video: {
        'width': width.toJS,
        'height': height.toJS,
      }.jsify()!,
    );

    final stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    _video!.srcObject = stream;
    await _video!.play().toDart;

    _isCapturing = true;
    _captureTimer = Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (_) => _capture(),
    );
  }

  Future<void> _capture() async {
    if (!_isCapturing || _video == null || _canvas == null) return;

    final sw = Stopwatch()..start();

    final ctx = _canvas!.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(_video!, 0, 0);

    final blob = await _canvas!.toBlob2('image/jpeg', 0.85);

    final reader = web.FileReader();
    final completer = Completer<Uint8List>();

    reader.onload = ((web.Event e) {
      final result = reader.result;
      if (result != null) {
        completer.complete((result as JSArrayBuffer).toDart.asUint8List());
      }
    }).toJS;

    reader.readAsArrayBuffer(blob);
    final bytes = await completer.future;

    final totalMs = sw.elapsedMilliseconds;
    _onFrameTiming?.call(totalMs: totalMs, sizeBytes: bytes.length);

    _frameController.add(bytes);
  }

  @override
  void stop() {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;

    final stream = _video?.srcObject;
    if (stream != null) {
      final ms = stream as web.MediaStream;
      final tracks = ms.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
    }
  }

  @override
  Future<void> dispose() async {
    stop();
    await _frameController.close();
  }
}

extension on web.HTMLCanvasElement {
  Future<web.Blob> toBlob2(String type, double quality) {
    final completer = Completer<web.Blob>();
    toBlob(
      ((web.Blob? blob) {
        if (blob != null) completer.complete(blob);
      }).toJS,
      type,
      quality.toJS,
    );
    return completer.future;
  }
}
