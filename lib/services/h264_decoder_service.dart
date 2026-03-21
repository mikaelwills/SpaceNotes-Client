import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'debug_logger.dart';

class H264DecoderService {
  static const _controlChannel = MethodChannel('spacenotes/h264_decoder_control');
  static const _frameChannel = BasicMessageChannel<ByteData>('spacenotes/h264_decoder_frame', BinaryCodec());

  int _textureId = -1;
  bool _started = false;

  int get textureId => _textureId;
  bool get isStarted => _started;

  Future<void> start() async {
    if (_started) return;

    final result = await _controlChannel.invokeMethod<int>('start');
    _textureId = result ?? -1;
    _started = _textureId >= 0;
    debugLogger.info('H264_DECODER', 'Started, textureId=$_textureId');
  }

  void feedFrame(Uint8List h264Data, int seq, bool isKeyframe) {
    if (!_started) return;

    final header = ByteData(5);
    header.setUint32(0, seq, Endian.little);
    header.setUint8(4, isKeyframe ? 1 : 0);

    final payload = Uint8List(5 + h264Data.length);
    payload.setRange(0, 5, header.buffer.asUint8List());
    payload.setRange(5, 5 + h264Data.length, h264Data);

    _frameChannel.send(payload.buffer.asByteData());
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _textureId = -1;
    await _controlChannel.invokeMethod('stop');
    debugLogger.info('H264_DECODER', 'Stopped');
  }
}
