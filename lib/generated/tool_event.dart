// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class ToolEvent {
  ToolEvent({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.detail,
    required this.startedAt,
  });

  factory ToolEvent.fromJson(Map<String, dynamic> json) {
    return ToolEvent(
      id: json['id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      tool: json['tool'] ?? '',
      detail: json['detail'] ?? '',
      startedAt: Int64(json['startedAt'] ?? 0),
    );
  }

  final String id;

  final String sessionId;

  final String tool;

  final String detail;

  final Int64 startedAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(sessionId);
    encoder.writeString(tool);
    encoder.writeString(detail);
    encoder.writeI64(startedAt);
  }

  static ToolEvent decodeBsatn(BsatnDecoder decoder) {
    return ToolEvent(
      id: decoder.readString(),
      sessionId: decoder.readString(),
      tool: decoder.readString(),
      detail: decoder.readString(),
      startedAt: decoder.readI64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'tool': tool,
      'detail': detail,
      'startedAt': startedAt.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ToolEvent &&
            id == other.id &&
            sessionId == other.sessionId &&
            tool == other.tool &&
            detail == other.detail &&
            startedAt == other.startedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, sessionId, tool, detail, startedAt);
  }

  @override
  String toString() {
    return 'ToolEvent(id: $id, sessionId: $sessionId, tool: $tool, detail: $detail, startedAt: $startedAt)';
  }

  ToolEvent copyWith({
    String? id,
    String? sessionId,
    String? tool,
    String? detail,
    Int64? startedAt,
  }) {
    return ToolEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tool: tool ?? this.tool,
      detail: detail ?? this.detail,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class ToolEventDecoder extends RowDecoder<ToolEvent> {
  @override
  ToolEvent decode(BsatnDecoder decoder) {
    return ToolEvent.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(ToolEvent row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(ToolEvent row) {
    return row.toJson();
  }

  @override
  ToolEvent? fromJson(Map<String, dynamic> json) {
    return ToolEvent.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
