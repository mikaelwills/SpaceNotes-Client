// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class AgentActivity {
  AgentActivity({
    required this.agentId,
    required this.state,
    required this.lastToolEvent,
    required this.updatedAt,
  });

  factory AgentActivity.fromJson(Map<String, dynamic> json) {
    return AgentActivity(
      agentId: json['agentId'] ?? '',
      state: json['state'] ?? '',
      lastToolEvent: json['lastToolEvent'],
      updatedAt: Int64(json['updatedAt'] ?? 0),
    );
  }

  final String agentId;

  final String state;

  final String? lastToolEvent;

  final Int64 updatedAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(agentId);
    encoder.writeString(state);
    encoder.writeOption<String>(
        lastToolEvent, (value) => encoder.writeString(value));
    encoder.writeI64(updatedAt);
  }

  static AgentActivity decodeBsatn(BsatnDecoder decoder) {
    return AgentActivity(
      agentId: decoder.readString(),
      state: decoder.readString(),
      lastToolEvent: decoder.readOption<String>(() => decoder.readString()),
      updatedAt: decoder.readI64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'state': state,
      'lastToolEvent': lastToolEvent,
      'updatedAt': updatedAt.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentActivity &&
            agentId == other.agentId &&
            state == other.state &&
            lastToolEvent == other.lastToolEvent &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([agentId, state, lastToolEvent, updatedAt]);
  }

  @override
  String toString() {
    return 'AgentActivity(agentId: $agentId, state: $state, lastToolEvent: $lastToolEvent, updatedAt: $updatedAt)';
  }

  AgentActivity copyWith({
    String? agentId,
    String? state,
    String? lastToolEvent,
    Int64? updatedAt,
  }) {
    return AgentActivity(
      agentId: agentId ?? this.agentId,
      state: state ?? this.state,
      lastToolEvent: lastToolEvent ?? this.lastToolEvent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AgentActivityDecoder extends RowDecoder<AgentActivity> {
  @override
  AgentActivity decode(BsatnDecoder decoder) {
    return AgentActivity.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(AgentActivity row) {
    return row.agentId;
  }

  @override
  Map<String, dynamic>? toJson(AgentActivity row) {
    return row.toJson();
  }

  @override
  AgentActivity? fromJson(Map<String, dynamic> json) {
    return AgentActivity.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
