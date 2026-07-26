// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class Agent {
  Agent({
    required this.id,
    required this.baseName,
    required this.host,
    required this.clientId,
    required this.createdAt,
    required this.lastSeen,
    required this.contextUsed,
    required this.contextWindow,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] ?? '',
      baseName: json['baseName'] ?? '',
      host: json['host'] ?? '',
      clientId: json['clientId'] ?? '',
      createdAt: Int64(json['createdAt'] ?? 0),
      lastSeen: Int64(json['lastSeen'] ?? 0),
      contextUsed: Int64(json['contextUsed'] ?? 0),
      contextWindow: Int64(json['contextWindow'] ?? 0),
    );
  }

  final String id;

  final String baseName;

  final String host;

  final String clientId;

  final Int64 createdAt;

  final Int64 lastSeen;

  final Int64 contextUsed;

  final Int64 contextWindow;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(id);
    encoder.writeString(baseName);
    encoder.writeString(host);
    encoder.writeString(clientId);
    encoder.writeI64(createdAt);
    encoder.writeI64(lastSeen);
    encoder.writeU64(contextUsed);
    encoder.writeU64(contextWindow);
  }

  static Agent decodeBsatn(BsatnDecoder decoder) {
    return Agent(
      id: decoder.readString(),
      baseName: decoder.readString(),
      host: decoder.readString(),
      clientId: decoder.readString(),
      createdAt: decoder.readI64(),
      lastSeen: decoder.readI64(),
      contextUsed: decoder.readU64(),
      contextWindow: decoder.readU64(),
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
      'contextUsed': contextUsed.toInt(),
      'contextWindow': contextWindow.toInt(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Agent &&
            id == other.id &&
            baseName == other.baseName &&
            host == other.host &&
            clientId == other.clientId &&
            createdAt == other.createdAt &&
            lastSeen == other.lastSeen &&
            contextUsed == other.contextUsed &&
            contextWindow == other.contextWindow;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      baseName,
      host,
      clientId,
      createdAt,
      lastSeen,
      contextUsed,
      contextWindow
    ]);
  }

  @override
  String toString() {
    return 'Agent(id: $id, baseName: $baseName, host: $host, clientId: $clientId, createdAt: $createdAt, lastSeen: $lastSeen, contextUsed: $contextUsed, contextWindow: $contextWindow)';
  }

  Agent copyWith({
    String? id,
    String? baseName,
    String? host,
    String? clientId,
    Int64? createdAt,
    Int64? lastSeen,
    Int64? contextUsed,
    Int64? contextWindow,
  }) {
    return Agent(
      id: id ?? this.id,
      baseName: baseName ?? this.baseName,
      host: host ?? this.host,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      contextUsed: contextUsed ?? this.contextUsed,
      contextWindow: contextWindow ?? this.contextWindow,
    );
  }
}

class AgentDecoder extends RowDecoder<Agent> {
  @override
  Agent decode(BsatnDecoder decoder) {
    return Agent.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Agent row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Agent row) {
    return row.toJson();
  }

  @override
  Agent? fromJson(Map<String, dynamic> json) {
    return Agent.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
