import 'dart:async';
import 'dart:typed_data';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'debug_logger.dart';

const int kAudioSampleRate = 16000;
const int kChunkDurationMs = 20;
const int kSamplesPerChunk = kAudioSampleRate * kChunkDurationMs ~/ 1000;

class AudioService {
  final AudioStreamer _streamer = AudioStreamer();
  StreamSubscription? _captureSub;
  bool _muted = false;
  bool _capturing = false;
  bool _playbackStarted = false;
  int _audioSeq = 0;

  final List<double> _captureBuffer = [];

  void Function(Uint8List pcmChunk, int seq)? onAudioChunk;

  bool get isMuted => _muted;
  bool get isCapturing => _capturing;

  Future<void> startCapture() async {
    if (_capturing || kIsWeb) return;
    _capturing = true;
    _audioSeq = 0;
    _captureBuffer.clear();

    _streamer.sampleRate = kAudioSampleRate;

    _captureSub = _streamer.audioStream.listen(
      (List<double> samples) {
        if (_muted) return;
        _captureBuffer.addAll(samples);
        _drainBuffer();
      },
      onError: (Object error) {
        debugLogger.info('AUDIO_TX', 'Capture error: $error');
      },
      cancelOnError: false,
    );

    final actual = await _streamer.actualSampleRate;
    debugLogger.info('AUDIO_TX', 'Capture started, requested=${kAudioSampleRate}Hz actual=${actual}Hz');
  }

  void _drainBuffer() {
    while (_captureBuffer.length >= kSamplesPerChunk) {
      final chunk = _captureBuffer.sublist(0, kSamplesPerChunk);
      _captureBuffer.removeRange(0, kSamplesPerChunk);

      final pcm = _doublesToPcm16(chunk);
      _audioSeq++;
      onAudioChunk?.call(pcm, _audioSeq);
    }
  }

  Uint8List _doublesToPcm16(List<double> samples) {
    final bytes = ByteData(samples.length * 2);
    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final int16 = (clamped * 32767).toInt();
      bytes.setInt16(i * 2, int16, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  Future<void> startPlayback() async {
    if (_playbackStarted || kIsWeb) return;
    _playbackStarted = true;

    await FlutterPcmSound.setup(sampleRate: kAudioSampleRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(kSamplesPerChunk * 2);
    FlutterPcmSound.setFeedCallback((_) {});
    FlutterPcmSound.start();

    debugLogger.info('AUDIO_RX', 'Playback started at ${kAudioSampleRate}Hz');
  }

  void feedRemoteAudio(Uint8List pcm) {
    if (!_playbackStarted || kIsWeb) return;
    final int16List = _pcmBytesToInt16List(pcm);
    FlutterPcmSound.feed(PcmArrayInt16.fromList(int16List));
  }

  List<int> _pcmBytesToInt16List(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final result = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      result.add(bd.getInt16(i, Endian.little));
    }
    return result;
  }

  void toggleMute() {
    _muted = !_muted;
    debugLogger.info('AUDIO', 'Mute: $_muted');
  }

  void stopCapture() {
    _captureSub?.cancel();
    _captureSub = null;
    _capturing = false;
    _captureBuffer.clear();
    debugLogger.info('AUDIO_TX', 'Capture stopped');
  }

  void stopPlayback() {
    if (_playbackStarted) {
      FlutterPcmSound.release();
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
