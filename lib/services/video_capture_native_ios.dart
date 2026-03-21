import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'video_capture.dart';
import 'debug_logger.dart';

class NativeIosVideoCaptureService implements VideoCaptureService {
  static const _controlChannel = MethodChannel('spacenotes/native_video_control');
  static const _frameChannel = BasicMessageChannel<ByteData>('spacenotes/native_video', BinaryCodec());

  final _frameController = StreamController<CapturedFrame>.broadcast();
  bool _isCapturing = false;
  FrameTimingCallback? _onFrameTiming;
  int _frameCount = 0;
  int _previewTextureId = -1;

  int get previewTextureId => _previewTextureId;

  @override
  Stream<CapturedFrame> get frameStream => _frameController.stream;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> start({int fps = 10, int width = 320, int height = 240, String codec = 'jpeg', FrameTimingCallback? onFrameTiming}) async {
    _onFrameTiming = onFrameTiming;
    _frameCount = 0;

    _frameChannel.setMessageHandler((ByteData? message) async {
      if (message == null || message.lengthInBytes <= 10) return ByteData(0);

      final frameCodec = message.getUint8(0);
      final isKeyframe = message.getUint8(1) == 1;
      final encodeMicros = message.getUint32(2, Endian.little);
      final encodeMs = (encodeMicros / 1000).round();
      final dataSize = message.lengthInBytes - 10;

      final data = message.buffer.asUint8List(message.offsetInBytes + 10, dataSize);
      final dataCopy = Uint8List.fromList(data);

      _frameCount++;
      if (_frameCount <= 2 || _frameCount % 300 == 0) {
        final codecName = frameCodec == 0 ? 'JPEG' : 'H264';
        debugLogger.info('NATIVE_CAPTURE', 'Frame #$_frameCount, codec=$codecName, keyframe=$isKeyframe, encode=${encodeMs}ms, size=${dataCopy.length ~/ 1024}KB');
      }

      _onFrameTiming?.call(totalMs: encodeMs, encodeMs: encodeMs, sizeBytes: dataCopy.length);
      _frameController.add(CapturedFrame(data: dataCopy, codec: frameCodec, isKeyframe: isKeyframe));
      return ByteData(0);
    });

    final result = await _controlChannel.invokeMethod<int>('start', {
      'fps': fps,
      'width': width,
      'height': height,
      'quality': 0.8,
      'codec': codec,
    });

    _previewTextureId = result ?? -1;
    _isCapturing = true;
    debugLogger.info('NATIVE_CAPTURE', 'Started native iOS capture: ${fps}fps ${width}x$height codec=$codec textureId=$_previewTextureId');
  }

  Future<void> switchCamera() async {
    final result = await _controlChannel.invokeMethod<int>('switchCamera');
    _previewTextureId = result ?? -1;
    debugLogger.info('NATIVE_CAPTURE', 'Switched camera, textureId=$_previewTextureId');
  }

  @override
  void stop() {
    _isCapturing = false;
    _frameChannel.setMessageHandler(null);
    _controlChannel.invokeMethod('stop');
    _previewTextureId = -1;
    debugLogger.info('NATIVE_CAPTURE', 'Stopped');
  }

  @override
  Future<void> dispose() async {
    stop();
    await _frameController.close();
  }
}
