// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class Session {
  Session({
    required this.id,
    required this.baseName,
    required this.host,
    required this.clientId,
    required this.createdAt,
    required this.lastSeen,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] ?? '',
      baseName: json['baseName'] ?? '',
      host: json['host'] ?? '',
      clientId: json['clientId'] ?? '',
      createdAt: Int64(json['createdAt'] ?? 0),
      lastSeen: Int64(json['lastSeen'] ?? 0),
    );
  }

  final String id;

  final String baseName;

  final String host;

  final String clientId;

  final Int64 createdAt;

  final Int64 lastSeen;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(baseName);
    encoder.writeString(host);
    encoder.writeString(clientId);
    encoder.writeI64(createdAt);
    encoder.writeI64(lastSeen);
  }

  static Session decodeBsatn(BsatnDecoder decoder) {
    return Session(
      id: decoder.readString(),
      baseName: decoder.readString(),
      host: decoder.readString(),
      clientId: decoder.readString(),
      createdAt: decoder.readI64(),
      lastSeen: decoder.readI64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baseName': baseName,
      'host': host,
      'clientId': clientId,
      'createdAt': createdAt.toInt(),
      'lastSeen': lastSeen.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Session &&
            id == other.id &&
            baseName == other.baseName &&
            host == other.host &&
            clientId == other.clientId &&
            createdAt == other.createdAt &&
            lastSeen == other.lastSeen;
  }

  @override
  int get hashCode {
    return Object.hash(id, baseName, host, clientId, createdAt, lastSeen);
  }

  @override
  String toString() {
    return 'Session(id: $id, baseName: $baseName, host: $host, clientId: $clientId, createdAt: $createdAt, lastSeen: $lastSeen)';
  }

  Session copyWith({
    String? id,
    String? baseName,
    String? host,
    String? clientId,
    Int64? createdAt,
    Int64? lastSeen,
  }) {
    return Session(
      id: id ?? this.id,
      baseName: baseName ?? this.baseName,
      host: host ?? this.host,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class SessionDecoder extends RowDecoder<Session> {
  @override
  Session decode(BsatnDecoder decoder) {
    return Session.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Session row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Session row) {
    return row.toJson();
  }

  @override
  Session? fromJson(Map<String, dynamic> json) {
    return Session.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
