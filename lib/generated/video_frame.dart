// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class VideoFrame {
  final Int64 sessionId;
  final Identity from;
  final int seq;
  final List<int> jpeg;

  VideoFrame({
    required this.sessionId,
    required this.from,
    required this.seq,
    required this.jpeg,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(sessionId);
    encoder.writeIdentity(from);
    encoder.writeU32(seq);
    encoder.writeByteArray(jpeg);
  }

  static VideoFrame decodeBsatn(BsatnDecoder decoder) {
    return VideoFrame(
      sessionId: decoder.readU64(),
      from: decoder.readIdentity(),
      seq: decoder.readU32(),
      jpeg: decoder.readByteArray(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId.toInt(),
      'from': from.toJson(),
      'seq': seq,
      'jpeg': jpeg,
    };
  }

  factory VideoFrame.fromJson(Map<String, dynamic> json) {
    return VideoFrame(
      sessionId: Int64((json['sessionId'] as int?) ?? 0),
      from: Identity.fromJson(json['from'] as String),
      seq: (json['seq'] as int?) ?? 0,
      jpeg: (json['jpeg'] as List?)?.cast<int>() ?? [],
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
