// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class AudioFrame {
  AudioFrame({
    required this.callId,
    required this.from,
    required this.seq,
    required this.pcm,
  });

  factory AudioFrame.fromJson(Map<String, dynamic> json) {
    return AudioFrame(
      callId: Int64(json['callId'] ?? 0),
      from: Identity.fromJson(json['from'] ?? ''),
      seq: json['seq'] ?? 0,
      pcm: json['pcm'],
    );
  }

  final Int64 callId;

  final Identity from;

  final int seq;

  final List<int> pcm;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(callId);
    encoder.writeIdentity(from);
    encoder.writeU32(seq);
    encoder.writeByteArray(pcm);
  }

  static AudioFrame decodeBsatn(BsatnDecoder decoder) {
    return AudioFrame(
      callId: decoder.readU64(),
      from: decoder.readIdentity(),
      seq: decoder.readU32(),
      pcm: decoder.readByteArray(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId.toInt(),
      'from': from.toJson(),
      'seq': seq,
      'pcm': pcm,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioFrame &&
            callId == other.callId &&
            from == other.from &&
            seq == other.seq &&
            pcm == other.pcm;
  }

  @override
  int get hashCode {
    return Object.hashAll([callId, from, seq, pcm]);
  }

  @override
  String toString() {
    return 'AudioFrame(callId: $callId, from: $from, seq: $seq, pcm: $pcm)';
  }

  AudioFrame copyWith({
    Int64? callId,
    Identity? from,
    int? seq,
    List<int>? pcm,
  }) {
    return AudioFrame(
      callId: callId ?? this.callId,
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
  bool get hasPrimaryKey {
    return false;
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
