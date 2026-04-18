// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class PermissionRequest {
  PermissionRequest({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.input,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json['id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      tool: json['tool'] ?? '',
      input: json['input'] ?? '',
      status: json['status'] ?? '',
      createdAt: Int64(json['createdAt'] ?? 0),
      resolvedAt: json['resolvedAt'] == null ? null : Int64(json['resolvedAt']),
    );
  }

  final String id;

  final String sessionId;

  final String tool;

  final String input;

  final String status;

  final Int64 createdAt;

  final Int64? resolvedAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(sessionId);
    encoder.writeString(tool);
    encoder.writeString(input);
    encoder.writeString(status);
    encoder.writeI64(createdAt);
    encoder.writeOption<Int64>(resolvedAt, (value) => encoder.writeI64(value));
  }

  static PermissionRequest decodeBsatn(BsatnDecoder decoder) {
    return PermissionRequest(
      id: decoder.readString(),
      sessionId: decoder.readString(),
      tool: decoder.readString(),
      input: decoder.readString(),
      status: decoder.readString(),
      createdAt: decoder.readI64(),
      resolvedAt: decoder.readOption<Int64>(() => decoder.readI64()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'tool': tool,
      'input': input,
      'status': status,
      'createdAt': createdAt.toInt(),
      'resolvedAt': resolvedAt?.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PermissionRequest &&
            id == other.id &&
            sessionId == other.sessionId &&
            tool == other.tool &&
            input == other.input &&
            status == other.status &&
            createdAt == other.createdAt &&
            resolvedAt == other.resolvedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
        id, sessionId, tool, input, status, createdAt, resolvedAt);
  }

  @override
  String toString() {
    return 'PermissionRequest(id: $id, sessionId: $sessionId, tool: $tool, input: $input, status: $status, createdAt: $createdAt, resolvedAt: $resolvedAt)';
  }

  PermissionRequest copyWith({
    String? id,
    String? sessionId,
    String? tool,
    String? input,
    String? status,
    Int64? createdAt,
    Int64? resolvedAt,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tool: tool ?? this.tool,
      input: input ?? this.input,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class PermissionRequestDecoder extends RowDecoder<PermissionRequest> {
  @override
  PermissionRequest decode(BsatnDecoder decoder) {
    return PermissionRequest.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(PermissionRequest row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(PermissionRequest row) {
    return row.toJson();
  }

  @override
  PermissionRequest? fromJson(Map<String, dynamic> json) {
    return PermissionRequest.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
