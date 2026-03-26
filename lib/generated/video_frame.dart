// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class VideoFrame {
  final Int64 sessionId;
  final Identity from;
  final int seq;
  final int codec;
  final bool isKeyframe;
  final List<int> data;

  VideoFrame({
    required this.sessionId,
    required this.from,
    required this.seq,
    required this.codec,
    required this.isKeyframe,
    required this.data,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(sessionId);
    encoder.writeIdentity(from);
    encoder.writeU32(seq);
    encoder.writeU8(codec);
    encoder.writeBool(isKeyframe);
    encoder.writeByteArray(data);
  }

  static VideoFrame decodeBsatn(BsatnDecoder decoder) {
    return VideoFrame(
      sessionId: decoder.readU64(),
      from: decoder.readIdentity(),
      seq: decoder.readU32(),
      codec: decoder.readU8(),
      isKeyframe: decoder.readBool(),
      data: decoder.readByteArray(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId.toInt(),
      'from': from.toJson(),
      'seq': seq,
      'codec': codec,
      'isKeyframe': isKeyframe,
      'data': data,
    };
  }

  factory VideoFrame.fromJson(Map<String, dynamic> json) {
    return VideoFrame(
      sessionId: Int64(json['sessionId'] ?? 0),
      from: Identity.fromJson(json['from'] ?? ''),
      seq: json['seq'] ?? 0,
      codec: json['codec'] ?? 0,
      isKeyframe: json['isKeyframe'] ?? false,
      data: List<int>.from(json['data'] ?? []),
    );
  }

}

class VideoFrameDecoder extends RowDecoder<VideoFrame> {
  @override
  VideoFrame decode(BsatnDecoder decoder) {
    return VideoFrame.decodeBsatn(decoder);
  }

  @override
  dynamic getPrimaryKey(VideoFrame row) {
    return null;
  }

  @override
  Map<String, dynamic>? toJson(VideoFrame row) => row.toJson();

  @override
  VideoFrame? fromJson(Map<String, dynamic> json) => VideoFrame.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
