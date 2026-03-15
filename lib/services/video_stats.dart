class RollingBuffer {
  final List<double> _data;
  int _cursor = 0;
  int _count = 0;

  RollingBuffer(int size) : _data = List.filled(size, 0.0);

  void add(double value) {
    _data[_cursor] = value;
    _cursor = (_cursor + 1) % _data.length;
    if (_count < _data.length) _count++;
  }

  double get average {
    if (_count == 0) return 0;
    double sum = 0;
    for (int i = 0; i < _count; i++) {
      sum += _data[i];
    }
    return sum / _count;
  }
}

class FpsCounter {
  int _frames = 0;
  int _lastResetMs;
  double _fps = 0;

  FpsCounter() : _lastResetMs = _nowMs();

  void tick() {
    _frames++;
    final now = _nowMs();
    final elapsed = now - _lastResetMs;
    if (elapsed >= 1000) {
      _fps = _frames * 1000.0 / elapsed;
      _frames = 0;
      _lastResetMs = now;
    }
  }

  double get fps => _fps;

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class VideoStats {
  final captureMs = RollingBuffer(60);
  final yuvToRgbMs = RollingBuffer(60);
  final jpegEncodeMs = RollingBuffer(60);
  final sendFps = FpsCounter();
  final sendSizeBytes = RollingBuffer(60);
  int totalSent = 0;

  final receiveFps = FpsCounter();
  final receiveSizeBytes = RollingBuffer(60);
  int totalReceived = 0;
  int? _lastReceivedSeq;
  int droppedFrames = 0;

  int _lastArrivalMs = 0;
  final arrivalToDisplayMs = RollingBuffer(60);

  void recordCapture({required int totalMs, int? yuvMs, int? encodeMs, required int sizeBytes}) {
    captureMs.add(totalMs.toDouble());
    if (yuvMs != null) yuvToRgbMs.add(yuvMs.toDouble());
    if (encodeMs != null) jpegEncodeMs.add(encodeMs.toDouble());
  }

  void recordSend({required int seq, required int sizeBytes}) {
    sendFps.tick();
    sendSizeBytes.add(sizeBytes.toDouble());
    totalSent++;
  }

  void recordReceive({required int seq, required int sizeBytes}) {
    receiveFps.tick();
    receiveSizeBytes.add(sizeBytes.toDouble());
    totalReceived++;
    _lastArrivalMs = DateTime.now().millisecondsSinceEpoch;

    if (_lastReceivedSeq != null && seq > _lastReceivedSeq! + 1) {
      droppedFrames += seq - _lastReceivedSeq! - 1;
    }
    _lastReceivedSeq = seq;
  }

  void recordDisplay() {
    if (_lastArrivalMs > 0) {
      final delta = DateTime.now().millisecondsSinceEpoch - _lastArrivalMs;
      arrivalToDisplayMs.add(delta.toDouble());
    }
  }

  VideoStatsSnapshot snapshot() {
    return VideoStatsSnapshot(
      sendFps: sendFps.fps,
      receiveFps: receiveFps.fps,
      avgCaptureMs: captureMs.average,
      avgYuvMs: yuvToRgbMs.average,
      avgEncodeMs: jpegEncodeMs.average,
      avgSendKB: sendSizeBytes.average / 1024,
      avgReceiveKB: receiveSizeBytes.average / 1024,
      avgDisplayLatencyMs: arrivalToDisplayMs.average,
      droppedFrames: droppedFrames,
      totalSent: totalSent,
      totalReceived: totalReceived,
    );
  }
}

class VideoStatsSnapshot {
  final double sendFps;
  final double receiveFps;
  final double avgCaptureMs;
  final double avgYuvMs;
  final double avgEncodeMs;
  final double avgSendKB;
  final double avgReceiveKB;
  final double avgDisplayLatencyMs;
  final int droppedFrames;
  final int totalSent;
  final int totalReceived;

  const VideoStatsSnapshot({
    required this.sendFps,
    required this.receiveFps,
    required this.avgCaptureMs,
    required this.avgYuvMs,
    required this.avgEncodeMs,
    required this.avgSendKB,
    required this.avgReceiveKB,
    required this.avgDisplayLatencyMs,
    required this.droppedFrames,
    required this.totalSent,
    required this.totalReceived,
  });
}
