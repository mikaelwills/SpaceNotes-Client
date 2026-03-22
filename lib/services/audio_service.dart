import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'debug_logger.dart';
import 'video_stats.dart';

const int kTimestampBytes = 8;

class AudioService {
  static const _captureControl = MethodChannel('spacenotes/native_audio_control');
  static const _captureChannel = BasicMessageChannel<ByteData>('spacenotes/native_audio', BinaryCodec());
  static const _playbackControl = MethodChannel('spacenotes/native_audio_playback_control');
  static const _playbackChannel = BasicMessageChannel<ByteData>('spacenotes/native_audio_playback', BinaryCodec());

  bool _muted = false;
  bool _capturing = false;
  bool _playbackStarted = false;
  int _audioSeq = 0;
  final audioLatencyMs = RollingBuffer(50);

  void Function(Uint8List pcmChunk, int seq)? onAudioChunk;

  bool get isMuted => _muted;
  bool get isCapturing => _capturing;

  Future<void> startCapture() async {
    if (_capturing || kIsWeb) return;
    _capturing = true;
    _audioSeq = 0;

    final micStatus = await Permission.microphone.request();
    debugLogger.info('AUDIO_TX', 'Mic permission: $micStatus');
    if (!micStatus.isGranted) {
      debugLogger.info('AUDIO_TX', 'Mic permission denied, skipping capture');
      _capturing = false;
      return;
    }

    _captureChannel.setMessageHandler((ByteData? message) async {
      if (message == null || _muted) return ByteData(0);
      final pcm = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      _audioSeq++;
      if (_audioSeq <= 3 || _audioSeq % 250 == 0) {
        debugLogger.info('AUDIO_TX', 'Chunk #$_audioSeq | ${pcm.length}B');
      }
      final stamped = ByteData(kTimestampBytes + pcm.length);
      stamped.setInt64(0, DateTime.now().millisecondsSinceEpoch, Endian.little);
      stamped.buffer.asUint8List().setRange(kTimestampBytes, kTimestampBytes + pcm.length, pcm);
      onAudioChunk?.call(stamped.buffer.asUint8List(), _audioSeq);
      return ByteData(0);
    });

    await _captureControl.invokeMethod('start');
    debugLogger.info('AUDIO_TX', 'Native capture started');
  }

  Future<void> startPlayback() async {
    if (_playbackStarted || kIsWeb) return;
    _playbackStarted = true;
    await _playbackControl.invokeMethod('start');
    debugLogger.info('AUDIO_RX', 'Native playback started');
  }

  int _feedCount = 0;

  void feedRemoteAudio(Uint8List pcm) {
    if (!_playbackStarted || kIsWeb) return;
    _feedCount++;

    if (pcm.length > kTimestampBytes) {
      final bd = ByteData.sublistView(pcm);
      final sentMs = bd.getInt64(0, Endian.little);
      final latency = DateTime.now().millisecondsSinceEpoch - sentMs;
      audioLatencyMs.add(latency.toDouble());

      if (_feedCount <= 3 || _feedCount % 250 == 0) {
        debugLogger.info('AUDIO_RX', 'Feed #$_feedCount | ${pcm.length}B | latency=${latency}ms');
      }

      final audioOnly = pcm.sublist(kTimestampBytes);
      _playbackChannel.send(ByteData.sublistView(audioOnly));
    }
  }

  void toggleMute() {
    _muted = !_muted;
    debugLogger.info('AUDIO', 'Mute: $_muted');
  }

  void stopCapture() {
    _captureChannel.setMessageHandler(null);
    _captureControl.invokeMethod('stop');
    _capturing = false;
    debugLogger.info('AUDIO_TX', 'Capture stopped');
  }

  void stopPlayback() {
    if (_playbackStarted) {
      _playbackControl.invokeMethod('stop');
      _playbackStarted = false;
      debugLogger.info('AUDIO_RX', 'Playback stopped');
    }
  }

  void dispose() {
    stopCapture();
    stopPlayback();
    onAudioChunk = null;
  }
}
