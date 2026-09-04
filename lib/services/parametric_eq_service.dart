import 'package:flutter/services.dart';

class ParametricEqService {
  static const MethodChannel _channel =
      MethodChannel('spacenotes/parametric_eq_playback');

  Future<bool> load(String path) async {
    final result = await _channel.invokeMethod<bool>('load', {'path': path});
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
