import 'dart:js_interop';
import 'dart:typed_data';

@JS('SpaceNotesCodecs.startDecoder')
external void _jsStartDecoder(String canvasId);

@JS('SpaceNotesCodecs.decodeFrame')
external void _jsDecodeFrame(JSUint8Array data, bool isKeyframe);

@JS('SpaceNotesCodecs.stopDecoder')
external void _jsStopDecoder();

class WebH264Decoder {
  static const canvasId = 'spacenotes-h264-decoder';
  bool _started = false;
  int _lastSeq = -1;
  bool _hasValidReference = false;

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _jsStartDecoder(canvasId);
    _started = true;
  }

  void feedFrame(Uint8List data, int seq, bool isKeyframe) {
    if (!_started) return;

    if (_lastSeq >= 0 && seq > _lastSeq + 1) {
      _hasValidReference = false;
    }
    _lastSeq = seq;

    if (isKeyframe) {
      _hasValidReference = true;
    } else if (!_hasValidReference) {
      return;
    }

    _jsDecodeFrame(data.toJS, isKeyframe);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _hasValidReference = false;
    _lastSeq = -1;
    _jsStopDecoder();
  }
}
