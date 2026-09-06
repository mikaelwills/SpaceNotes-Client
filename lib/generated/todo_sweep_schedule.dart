// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class TodoSweepSchedule {
  TodoSweepSchedule({
    required this.scheduledId,
    required this.scheduledAt,
  });

  factory TodoSweepSchedule.fromJson(Map<String, dynamic> json) {
    return TodoSweepSchedule(
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

  static TodoSweepSchedule decodeBsatn(BsatnDecoder decoder) {
    return TodoSweepSchedule(
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
        other is TodoSweepSchedule &&
            scheduledId == other.scheduledId &&
            scheduledAt == other.scheduledAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([scheduledId, scheduledAt]);
  }

  @override
  String toString() {
    return 'TodoSweepSchedule(scheduledId: $scheduledId, scheduledAt: $scheduledAt)';
  }

  TodoSweepSchedule copyWith({
    Int64? scheduledId,
    ScheduleAt? scheduledAt,
  }) {
    return TodoSweepSchedule(
      scheduledId: scheduledId ?? this.scheduledId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}

class TodoSweepScheduleDecoder extends RowDecoder<TodoSweepSchedule> {
  @override
  TodoSweepSchedule decode(BsatnDecoder decoder) {
    return TodoSweepSchedule.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(TodoSweepSchedule row) {
    return row.scheduledId;
  }

  @override
  Map<String, dynamic>? toJson(TodoSweepSchedule row) {
    return row.toJson();
  }

  @override
  TodoSweepSchedule? fromJson(Map<String, dynamic> json) {
    return TodoSweepSchedule.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
