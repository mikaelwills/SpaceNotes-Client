import 'dart:typed_data';

class WebH264Decoder {
  bool get isStarted => false;

  void start() {}
  void feedFrame(Uint8List data, int seq, bool isKeyframe) {}
  void stop() {}
}
