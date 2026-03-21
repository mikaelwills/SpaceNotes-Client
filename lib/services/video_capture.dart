import 'dart:async';
import 'dart:typed_data';

typedef FrameTimingCallback = void Function({required int totalMs, int? yuvMs, int? encodeMs, required int sizeBytes});

class CapturedFrame {
  final Uint8List data;
  final int codec;
  final bool isKeyframe;

  CapturedFrame({required this.data, required this.codec, required this.isKeyframe});
}

abstract class VideoCaptureService {
  Future<void> start({int fps = 10, int width = 320, int height = 240, String codec = 'jpeg', FrameTimingCallback? onFrameTiming});
  void stop();
  Stream<CapturedFrame> get frameStream;
  bool get isCapturing;
  Future<void> dispose();
}
