import 'dart:async';
import 'dart:typed_data';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
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

  double? _actualSampleRate;
  double _resamplePhase = 0.0;
  List<double> _resampleCarry = [];
  List<double> _preResampleBuffer = [];

  final List<double> _captureBuffer = [];

  void Function(Uint8List pcmChunk, int seq)? onAudioChunk;

  bool get isMuted => _muted;
  bool get isCapturing => _capturing;

  Future<void> startCapture() async {
    if (_capturing || kIsWeb) return;
    _capturing = true;
    _audioSeq = 0;
    _captureBuffer.clear();
    _actualSampleRate = null;
    _resamplePhase = 0.0;
    _resampleCarry = [];
    _preResampleBuffer = [];

    final micStatus = await Permission.microphone.request();
    debugLogger.info('AUDIO_TX', 'Mic permission: $micStatus');
    if (!micStatus.isGranted) {
      debugLogger.info('AUDIO_TX', 'Mic permission denied, skipping capture');
      _capturing = false;
      return;
    }

    _streamer.sampleRate = kAudioSampleRate;

    bool requestedRate = false;

    _captureSub = _streamer.audioStream.listen(
      (List<double> samples) {
        if (!requestedRate) {
          requestedRate = true;
          _streamer.actualSampleRate.then((actual) {
            _actualSampleRate = actual.toDouble();
            debugLogger.info('AUDIO_TX', 'Capture started, actual=${actual}Hz, needsResample=${_actualSampleRate != kAudioSampleRate}');
            if (_preResampleBuffer.isNotEmpty) {
              final resampled = _resampleToTarget(_preResampleBuffer);
              _captureBuffer.addAll(resampled);
              _preResampleBuffer = [];
              _drainBuffer();
            }
          });
        }

        if (_muted) return;

        if (_actualSampleRate == null) {
          _preResampleBuffer.addAll(samples);
          return;
        }

        final resampled = _resampleToTarget(samples);
        _captureBuffer.addAll(resampled);
        _drainBuffer();
      },
      onError: (Object error) {
        debugLogger.info('AUDIO_TX', 'Capture error: $error');
      },
      cancelOnError: false,
    );
  }

  List<double> _resampleToTarget(List<double> input) {
    final inputRate = _actualSampleRate!;
    if ((inputRate - kAudioSampleRate).abs() < 1.0) return input;

    final ratio = inputRate / kAudioSampleRate;
    final source = [..._resampleCarry, ...input];
    final maxOutput = ((source.length - _resamplePhase) / ratio).floor();
    if (maxOutput <= 0) {
      _resampleCarry = source;
      return [];
    }

    final output = List<double>.filled(maxOutput, 0.0);
    double pos = _resamplePhase;

    for (int i = 0; i < maxOutput; i++) {
      final idx = pos.floor();
      final frac = pos - idx;
      if (idx + 1 < source.length) {
        output[i] = source[idx] * (1.0 - frac) + source[idx + 1] * frac;
      } else if (idx < source.length) {
        output[i] = source[idx];
      }
      pos += ratio;
    }

    final consumed = pos.floor();
    _resamplePhase = pos - consumed;
    _resampleCarry = consumed < source.length ? source.sublist(consumed) : [];

    return output;
  }

  void _drainBuffer() {
    while (_captureBuffer.length >= kSamplesPerChunk) {
      final chunk = _captureBuffer.sublist(0, kSamplesPerChunk);
      _captureBuffer.removeRange(0, kSamplesPerChunk);

      final pcm = _doublesToPcm16(chunk);
      _audioSeq++;
      if (_audioSeq <= 3 || _audioSeq % 250 == 0) {
        debugLogger.info('AUDIO_TX', 'Chunk #$_audioSeq | ${pcm.length}B | buffer=${_captureBuffer.length}');
      }
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

    try {
      await FlutterPcmSound.setup(
        sampleRate: kAudioSampleRate,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
      await FlutterPcmSound.setFeedThreshold(kSamplesPerChunk * 2);
      FlutterPcmSound.setFeedCallback((_) {});
      FlutterPcmSound.start();
      _playbackStarted = true;
      debugLogger.info('AUDIO_RX', 'Playback started at ${kAudioSampleRate}Hz');
    } catch (e) {
      debugLogger.info('AUDIO_RX', 'Playback setup failed: $e');
      _playbackStarted = false;
    }
  }

  int _feedCount = 0;

  void feedRemoteAudio(Uint8List pcm) {
    if (!_playbackStarted || kIsWeb) return;
    _feedCount++;
    if (_feedCount <= 3 || _feedCount % 250 == 0) {
      debugLogger.info('AUDIO_RX', 'Feed #$_feedCount | ${pcm.length}B');
    }
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
    _preResampleBuffer = [];
    _resampleCarry = [];
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
