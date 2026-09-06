import 'package:flutter/services.dart';

class ParametricEqService {
  ParametricEqService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel =
      MethodChannel('spacenotes/parametric_eq_playback');

  ValueChanged<bool>? onPlaybackStateChanged;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'playbackStateChanged') return null;
    final args = call.arguments as Map?;
    final isPlaying = args?['isPlaying'] as bool?;
    if (isPlaying != null) onPlaybackStateChanged?.call(isPlaying);
    return null;
  }

  Future<bool> load(String path, {String? title}) async {
    final result = await _channel.invokeMethod<bool>('load', {
      'path': path,
      if (title != null) 'title': title,
    });
    return result ?? false;
  }

  Future<void> play() => _channel.invokeMethod('play');

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> seek(Duration position) => _channel.invokeMethod('seek', {
        'seconds': position.inMilliseconds / 1000,
      });

  Future<Duration> position() async {
    final seconds = await _channel.invokeMethod<double>('position');
    return Duration(milliseconds: ((seconds ?? 0) * 1000).round());
  }

  Future<Duration> duration() async {
    final seconds = await _channel.invokeMethod<double>('duration');
    return Duration(milliseconds: ((seconds ?? 0) * 1000).round());
  }

  Future<void> setEq({
    required double frequencyHz,
    required double gainDb,
    required double bandwidth,
  }) =>
      _channel.invokeMethod('setEq', {
        'frequency': frequencyHz,
        'gainDb': gainDb,
        'bandwidth': bandwidth,
      });

  Future<void> clearEq() => _channel.invokeMethod('clearEq');

  Future<void> stop() => _channel.invokeMethod('stop');
}
