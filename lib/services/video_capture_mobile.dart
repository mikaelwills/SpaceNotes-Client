import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'video_capture.dart';
import 'debug_logger.dart';

class MobileVideoCaptureService implements VideoCaptureService {
  CameraController? _camera;
  final _frameController = StreamController<CapturedFrame>.broadcast();
  bool _isCapturing = false;
  int _targetFps = 10;
  DateTime _lastFrame = DateTime.now();
  int _frameCount = 0;
  FrameTimingCallback? _onFrameTiming;

  CameraController? get cameraController => _camera;

  @override
  Stream<CapturedFrame> get frameStream => _frameController.stream;

  @override
  bool get isCapturing => _isCapturing;

  ResolutionPreset _resolutionForSize(int width, int height) {
    final pixels = width * height;
    if (pixels >= 1920 * 1080) return ResolutionPreset.max;
    if (pixels >= 1280 * 720) return ResolutionPreset.high;
    if (pixels >= 640 * 480) return ResolutionPreset.medium;
    return ResolutionPreset.low;
  }

  @override
  Future<void> start({int fps = 10, int width = 320, int height = 240, String codec = 'jpeg', FrameTimingCallback? onFrameTiming}) async {
    _targetFps = fps;
    _onFrameTiming = onFrameTiming;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugLogger.warning('CAPTURE', 'No cameras available');
      return;
    }

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final preset = _resolutionForSize(width, height);
    debugLogger.info('CAPTURE', 'Using resolution preset: $preset for ${width}x$height');

    _camera = CameraController(
      front,
      preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _camera!.initialize();
    _isCapturing = true;
    _lastFrame = DateTime.now();
    _frameCount = 0;

    await _camera!.startImageStream(_onFrame);
    debugLogger.info('CAPTURE', 'Started mobile capture at ${fps}fps');
  }

  void _onFrame(CameraImage frame) {
    if (!_isCapturing) return;

    final now = DateTime.now();
    final interval = Duration(milliseconds: (1000 / _targetFps).round());
    if (now.difference(_lastFrame) < interval) return;
    _lastFrame = now;

    final sw = Stopwatch()..start();
    try {
      final rgb = _convertYUV420toRGB(frame);
      final yuvMs = sw.elapsedMilliseconds;

      final jpeg = Uint8List.fromList(img.encodeJpg(rgb, quality: 80));
      final totalMs = sw.elapsedMilliseconds;
      final encodeMs = totalMs - yuvMs;

      _frameCount++;
      if (_frameCount <= 2 || _frameCount % 300 == 0) {
        debugLogger.info('CAPTURE', 'YUV: ${yuvMs}ms, JPEG: ${encodeMs}ms, Total: ${totalMs}ms, Size: ${jpeg.length ~/ 1024}KB');
      }

      _onFrameTiming?.call(totalMs: totalMs, yuvMs: yuvMs, encodeMs: encodeMs, sizeBytes: jpeg.length);
      _frameController.add(CapturedFrame(data: jpeg, codec: 0, isKeyframe: true));
    } catch (e) {
      debugLogger.error('CAPTURE', 'Frame encode error: $e');
    }
  }

  img.Image _convertYUV420toRGB(CameraImage frame) {
    final width = frame.width;
    final height = frame.height;
    final image = img.Image(width: width, height: height);

    final yPlane = frame.planes[0].bytes;
    final yRowStride = frame.planes[0].bytesPerRow;

    if (frame.planes.length == 2) {
      final uvPlane = frame.planes[1].bytes;
      final uvRowStride = frame.planes[1].bytesPerRow;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yRowStride + x;
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * 2;

          final yVal = yPlane[yIndex];
          final uVal = uvPlane[uvIndex];
          final vVal = uvPlane[uvIndex + 1];

          int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
          int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128)).round().clamp(0, 255);
          int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    } else {
      final uPlane = frame.planes[1].bytes;
      final vPlane = frame.planes[2].bytes;
      final uvRowStride = frame.planes[1].bytesPerRow;
      final uvPixelStride = frame.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yRowStride + x;
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final yVal = yPlane[yIndex];
          final uVal = uPlane[uvIndex];
          final vVal = vPlane[uvIndex];

          int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
          int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128)).round().clamp(0, 255);
          int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }

    return image;
  }

  @override
  void stop() {
    _isCapturing = false;
    _camera?.stopImageStream();
    debugLogger.info('CAPTURE', 'Stopped mobile capture');
  }

  @override
  Future<void> dispose() async {
    stop();
    await _camera?.dispose();
    _camera = null;
    await _frameController.close();
  }
}
