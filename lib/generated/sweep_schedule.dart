// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class SweepSchedule {
  SweepSchedule({
    required this.scheduledId,
    required this.scheduledAt,
  });

  factory SweepSchedule.fromJson(Map<String, dynamic> json) {
    return SweepSchedule(
      scheduledId: Int64(json['scheduledId'] ?? 0),
      scheduledAt: ScheduleAt.fromJson(
          Map<String, dynamic>.from(json['scheduledAt'] ?? {})),
    );
  }

  final Int64 scheduledId;

  final ScheduleAt scheduledAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(scheduledId);
    scheduledAt.encodeBsatn(encoder);
  }

  static SweepSchedule decodeBsatn(BsatnDecoder decoder) {
    return SweepSchedule(
      scheduledId: decoder.readU64(),
      scheduledAt: ScheduleAt.decodeBsatn(decoder),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduledId': scheduledId.toInt(),
      'scheduledAt': scheduledAt.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SweepSchedule &&
            scheduledId == other.scheduledId &&
            scheduledAt == other.scheduledAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([scheduledId, scheduledAt]);
  }

  @override
  String toString() {
    return 'SweepSchedule(scheduledId: $scheduledId, scheduledAt: $scheduledAt)';
  }

  SweepSchedule copyWith({
    Int64? scheduledId,
    ScheduleAt? scheduledAt,
  }) {
    return SweepSchedule(
      scheduledId: scheduledId ?? this.scheduledId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}

class SweepScheduleDecoder extends RowDecoder<SweepSchedule> {
  @override
  SweepSchedule decode(BsatnDecoder decoder) {
    return SweepSchedule.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(SweepSchedule row) {
    return row.scheduledId;
  }

  @override
  Map<String, dynamic>? toJson(SweepSchedule row) {
    return row.toJson();
  }

  @override
  SweepSchedule? fromJson(Map<String, dynamic> json) {
    return SweepSchedule.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
