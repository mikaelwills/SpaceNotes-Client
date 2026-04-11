// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/codegen.dart';

class AudioFrame {
  AudioFrame({
    required this.sessionId,
    required this.from,
    required this.seq,
    required this.pcm,
  });

  factory AudioFrame.fromJson(Map<String, dynamic> json) {
    return AudioFrame(
      sessionId: Int64(json['sessionId'] ?? 0),
      from: Identity.fromJson(json['from'] ?? ''),
      seq: json['seq'] ?? 0,
      pcm: json['pcm'],
    );
  }

  final Int64 sessionId;

  final Identity from;

  final int seq;

  final List<int> pcm;

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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioFrame &&
            sessionId == other.sessionId &&
            from == other.from &&
            seq == other.seq &&
            pcm == other.pcm;
  }

  @override
  int get hashCode {
    return Object.hash(sessionId, from, seq, pcm);
  }

  @override
  String toString() {
    return 'AudioFrame(sessionId: $sessionId, from: $from, seq: $seq, pcm: $pcm)';
  }

  AudioFrame copyWith({
    Int64? sessionId,
    Identity? from,
    int? seq,
    List<int>? pcm,
  }) {
    return AudioFrame(
      sessionId: sessionId ?? this.sessionId,
      from: from ?? this.from,
      seq: seq ?? this.seq,
      pcm: pcm ?? this.pcm,
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
  Map<String, dynamic>? toJson(AudioFrame row) {
    return row.toJson();
  }

  @override
  AudioFrame? fromJson(Map<String, dynamic> json) {
    return AudioFrame.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
