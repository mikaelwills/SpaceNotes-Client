// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class SessionActivity {
  SessionActivity({
    required this.sessionId,
    required this.state,
    required this.lastToolEvent,
    required this.updatedAt,
  });

  factory SessionActivity.fromJson(Map<String, dynamic> json) {
    return SessionActivity(
      sessionId: json['sessionId'] ?? '',
      state: json['state'] ?? '',
      lastToolEvent: json['lastToolEvent'],
      updatedAt: Int64(json['updatedAt'] ?? 0),
    );
  }

  final String sessionId;

  final String state;

  final String? lastToolEvent;

  final Int64 updatedAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(sessionId);
    encoder.writeString(state);
    encoder.writeOption<String>(
        lastToolEvent, (value) => encoder.writeString(value));
    encoder.writeI64(updatedAt);
  }

  static SessionActivity decodeBsatn(BsatnDecoder decoder) {
    return SessionActivity(
      sessionId: decoder.readString(),
      state: decoder.readString(),
      lastToolEvent: decoder.readOption<String>(() => decoder.readString()),
      updatedAt: decoder.readI64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'state': state,
      'lastToolEvent': lastToolEvent,
      'updatedAt': updatedAt.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionActivity &&
            sessionId == other.sessionId &&
            state == other.state &&
            lastToolEvent == other.lastToolEvent &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(sessionId, state, lastToolEvent, updatedAt);
  }

  @override
  String toString() {
    return 'SessionActivity(sessionId: $sessionId, state: $state, lastToolEvent: $lastToolEvent, updatedAt: $updatedAt)';
  }

  SessionActivity copyWith({
    String? sessionId,
    String? state,
    String? lastToolEvent,
    Int64? updatedAt,
  }) {
    return SessionActivity(
      sessionId: sessionId ?? this.sessionId,
      state: state ?? this.state,
      lastToolEvent: lastToolEvent ?? this.lastToolEvent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SessionActivityDecoder extends RowDecoder<SessionActivity> {
  @override
  SessionActivity decode(BsatnDecoder decoder) {
    return SessionActivity.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(SessionActivity row) {
    return row.sessionId;
  }

  @override
  Map<String, dynamic>? toJson(SessionActivity row) {
    return row.toJson();
  }

  @override
  SessionActivity? fromJson(Map<String, dynamic> json) {
    return SessionActivity.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
