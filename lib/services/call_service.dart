import 'dart:async';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/client.dart';
import 'debug_logger.dart';
import 'video_capture.dart';
import 'video_capture_factory.dart';
import 'video_stats.dart';

class CallService {
  SpacetimeDbClient? _client;
  VideoCaptureService? _captureService;
  StreamSubscription? _frameSub;
  int _videoSeq = 0;
  Int64? _activeSessionId;
  VideoStats? videoStats;

  VideoCaptureService? get captureService => _captureService;
  bool get isCapturing => _captureService?.isCapturing ?? false;

  void setClient(SpacetimeDbClient? client) {
    _client = client;
  }

  Future<void> startCapture(Int64 sessionId, {int fps = 10, int width = 320, int height = 240}) async {
    _activeSessionId = sessionId;
    _videoSeq = 0;
    videoStats = VideoStats();

    _captureService = createVideoCaptureService();
    await _captureService!.start(
      fps: fps,
      width: width,
      height: height,
      onFrameTiming: ({required int totalMs, int? yuvMs, int? encodeMs, required int sizeBytes}) {
        videoStats?.recordCapture(totalMs: totalMs, yuvMs: yuvMs, encodeMs: encodeMs, sizeBytes: sizeBytes);
      },
    );

    _frameSub = _captureService!.frameStream.listen((jpeg) {
      if (_client == null || _activeSessionId == null) return;
      _videoSeq++;
      if (_videoSeq <= 5 || _videoSeq % 30 == 0) {
        debugLogger.info('VIDEO_TX', 'Sending frame #$_videoSeq, size=${jpeg.length}, session=$_activeSessionId');
      }
      videoStats?.recordSend(seq: _videoSeq, sizeBytes: jpeg.length);
      _client!.reducers.sendVideoFrame(
        sessionId: _activeSessionId!,
        seq: _videoSeq,
        jpeg: jpeg.toList(),
        isEventTable: true,
      );
    });

    debugLogger.info('CALL', 'Started capture at ${fps}fps ${width}x$height for session $sessionId');
  }

  void stopCapture() {
    _frameSub?.cancel();
    _frameSub = null;
    _captureService?.stop();
    _activeSessionId = null;
    videoStats = null;
    debugLogger.info('CALL', 'Stopped capture');
  }

  Future<void> requestCall(Identity callee) async {
    if (_client == null) return;
    await _client!.reducers.requestCall(callee: callee);
    debugLogger.info('CALL', 'Requested call to ${callee.toHexString.substring(0, 8)}');
  }

  Future<void> acceptCall(Int64 sessionId) async {
    if (_client == null) return;
    await _client!.reducers.acceptCall(sessionId: sessionId);
    debugLogger.info('CALL', 'Accepted call session $sessionId');
  }

  Future<void> endCall(Int64 sessionId) async {
    if (_client == null) return;
    stopCapture();
    await _client!.reducers.endCall(sessionId: sessionId);
    debugLogger.info('CALL', 'Ended call session $sessionId');
  }

  Future<void> dispose() async {
    stopCapture();
    await _captureService?.dispose();
    _captureService = null;
  }
}
