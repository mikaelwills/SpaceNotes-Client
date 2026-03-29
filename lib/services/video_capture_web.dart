import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'video_capture.dart';

@JS('SpaceNotesCodecs.startEncoder')
external void _jsStartEncoder(int width, int height, int fps, int keyframeInterval, JSFunction onFrame);

@JS('SpaceNotesCodecs.stopEncoder')
external void _jsStopEncoder();

class WebVideoCaptureService implements VideoCaptureService {
  final _frameController = StreamController<CapturedFrame>.broadcast();
  bool _isCapturing = false;
  Timer? _captureTimer;
  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  FrameTimingCallback? _onFrameTiming;
  String _codecMode = 'jpeg';

  @override
  Stream<CapturedFrame> get frameStream => _frameController.stream;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> start({int fps = 10, int width = 320, int height = 240, String codec = 'jpeg', FrameTimingCallback? onFrameTiming}) async {
    _onFrameTiming = onFrameTiming;
    _codecMode = codec;
    _isCapturing = true;

    if (codec == 'h264') {
      _startH264(width, height, fps);
    } else {
      _startJpeg(width, height, fps);
    }
  }

  void _startH264(int width, int height, int fps) {
    final onFrame = ((JSUint8Array jsData, bool isKeyframe, int size) {
      if (!_isCapturing) return;
      final data = jsData.toDart;
      _onFrameTiming?.call(totalMs: 0, sizeBytes: data.length);
      _frameController.add(CapturedFrame(data: Uint8List.fromList(data), codec: 1, isKeyframe: isKeyframe));
    }).toJS;

    _jsStartEncoder(width, height, fps, fps, onFrame);
  }

  void _startJpeg(int width, int height, int fps) async {
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

    _captureTimer = Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (_) => _captureJpeg(),
    );
  }

  Future<void> _captureJpeg() async {
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

    _frameController.add(CapturedFrame(data: bytes, codec: 0, isKeyframe: true));
  }

  @override
  void stop() {
    _isCapturing = false;

    if (_codecMode == 'h264') {
      _jsStopEncoder();
    } else {
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
