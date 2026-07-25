// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class Message {
  Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.text,
    required this.source,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      role: json['role'] ?? '',
      text: json['text'] ?? '',
      source: json['source'] ?? '',
      createdAt: Int64(json['createdAt'] ?? 0),
    );
  }

  final String id;

  final String sessionId;

  final String role;

  final String text;

  final String source;

  final Int64 createdAt;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(sessionId);
    encoder.writeString(role);
    encoder.writeString(text);
    encoder.writeString(source);
    encoder.writeI64(createdAt);
  }

  static Message decodeBsatn(BsatnDecoder decoder) {
    return Message(
      id: decoder.readString(),
      sessionId: decoder.readString(),
      role: decoder.readString(),
      text: decoder.readString(),
      source: decoder.readString(),
      createdAt: decoder.readI64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'text': text,
      'source': source,
      'createdAt': createdAt.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Message &&
            id == other.id &&
            sessionId == other.sessionId &&
            role == other.role &&
            text == other.text &&
            source == other.source &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, sessionId, role, text, source, createdAt]);
  }

  @override
  String toString() {
    return 'Message(id: $id, sessionId: $sessionId, role: $role, text: $text, source: $source, createdAt: $createdAt)';
  }

  Message copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? text,
    String? source,
    Int64? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      text: text ?? this.text,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MessageDecoder extends RowDecoder<Message> {
  @override
  Message decode(BsatnDecoder decoder) {
    return Message.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Message row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Message row) {
    return row.toJson();
  }

  @override
  Message? fromJson(Map<String, dynamic> json) {
    return Message.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
