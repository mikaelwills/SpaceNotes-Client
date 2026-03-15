import 'dart:async';
import 'dart:typed_data';

typedef FrameTimingCallback = void Function({required int totalMs, int? yuvMs, int? encodeMs, required int sizeBytes});

abstract class VideoCaptureService {
  Future<void> start({int fps = 10, int width = 320, int height = 240, FrameTimingCallback? onFrameTiming});
  void stop();
  Stream<Uint8List> get frameStream;
  bool get isCapturing;
  Future<void> dispose();
}
