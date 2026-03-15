// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class AudioFrame {
  final Int64 sessionId;
  final Identity from;
  final int seq;
  final List<int> pcm;

  AudioFrame({
    required this.sessionId,
    required this.from,
    required this.seq,
    required this.pcm,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(sessionId);
    encoder.writeIdentity(from);
    encoder.writeU32(seq);
    encoder.writeByteArray(pcm);
  }

  static AudioFrame decodeBsatn(BsatnDecoder decoder) {
    return AudioFrame(
      sessionId: decoder.readU64(),
      from: decoder.readIdentity(),
      seq: decoder.readU32(),
      pcm: decoder.readByteArray(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId.toInt(),
      'from': from.toJson(),
      'seq': seq,
      'pcm': pcm,
    };
  }

  factory AudioFrame.fromJson(Map<String, dynamic> json) {
    return AudioFrame(
      sessionId: Int64((json['sessionId'] as int?) ?? 0),
      from: Identity.fromJson(json['from'] as String),
      seq: (json['seq'] as int?) ?? 0,
      pcm: (json['pcm'] as List?)?.cast<int>() ?? [],
    );
  }

}

class AudioFrameDecoder extends RowDecoder<AudioFrame> {
  @override
  AudioFrame decode(BsatnDecoder decoder) {
    return AudioFrame.decodeBsatn(decoder);
  }

  @override
  dynamic getPrimaryKey(AudioFrame row) {
    return null;
  }

  @override
  Map<String, dynamic>? toJson(AudioFrame row) => row.toJson();

  @override
  AudioFrame? fromJson(Map<String, dynamic> json) => AudioFrame.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
