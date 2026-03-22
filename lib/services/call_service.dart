import 'dart:async';
import 'dart:typed_data';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/client.dart';
import 'audio_service.dart';
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
  AudioService? audioService;

  VideoCaptureService? get captureService => _captureService;
  bool get isCapturing => _captureService?.isCapturing ?? false;

  void setClient(SpacetimeDbClient? client) {
    _client = client;
  }

  Future<void> startCapture(Int64 sessionId, {int fps = 10, int width = 320, int height = 240, String codec = 'h264'}) async {
    _activeSessionId = sessionId;
    _videoSeq = 0;
    videoStats = VideoStats();

    _captureService = createVideoCaptureService();

    final txStart = DateTime.now();
    _frameSub = _captureService!.frameStream.listen((frame) {
      if (_client == null || _activeSessionId == null) return;
      _videoSeq++;
      if (_videoSeq % 300 == 0) {
        final elapsed = DateTime.now().difference(txStart).inMilliseconds / 1000.0;
        debugLogger.info('VIDEO_TX', 'Frame #$_videoSeq | fps: ${(_videoSeq / elapsed).toStringAsFixed(1)} | size: ${frame.data.length ~/ 1024}KB');
      }
      videoStats?.recordSend(seq: _videoSeq, sizeBytes: frame.data.length);
      _client!.reducers.sendVideoFrame(
        sessionId: _activeSessionId!,
        seq: _videoSeq,
        codec: frame.codec,
        isKeyframe: frame.isKeyframe,
        data: frame.data.toList(),
        isEventTable: true,
      );
    });

    await _captureService!.start(
      fps: fps,
      width: width,
      height: height,
      codec: codec,
      onFrameTiming: ({required int totalMs, int? yuvMs, int? encodeMs, required int sizeBytes}) {
        videoStats?.recordCapture(totalMs: totalMs, yuvMs: yuvMs, encodeMs: encodeMs, sizeBytes: sizeBytes);
      },
    );

    audioService = AudioService();
    audioService!.onAudioChunk = (Uint8List pcm, int seq) {
      if (_client == null || _activeSessionId == null) return;
      _client!.reducers.sendAudioFrame(
        sessionId: _activeSessionId!,
        seq: seq,
        pcm: pcm.toList(),
        isEventTable: true,
      );
    };
    await audioService!.startPlayback();
    await audioService!.startCapture();

    debugLogger.info('CALL', 'Started capture at ${fps}fps ${width}x$height for session $sessionId');
  }

  void stopCapture() {
    _frameSub?.cancel();
    _frameSub = null;
    _captureService?.stop();
    _captureService?.dispose();
    _captureService = null;
    audioService?.dispose();
    audioService = null;
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
