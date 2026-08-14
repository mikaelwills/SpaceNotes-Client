// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class ConnectedUser {
  ConnectedUser({
    required this.connectionId,
    required this.identity,
    required this.connectedAt,
    required this.name,
  });

  factory ConnectedUser.fromJson(Map<String, dynamic> json) {
    return ConnectedUser(
      connectionId: json['connectionId'] ?? '',
      identity: Identity.fromJson(json['identity'] ?? ''),
      connectedAt: Int64(json['connectedAt'] ?? 0),
      name: json['name'] ?? '',
    );
  }

  final String connectionId;

  final Identity identity;

  final Int64 connectedAt;

  final String name;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(connectionId);
    encoder.writeIdentity(identity);
    encoder.writeU64(connectedAt);
    encoder.writeString(name);
  }

  static ConnectedUser decodeBsatn(BsatnDecoder decoder) {
    return ConnectedUser(
      connectionId: decoder.readString(),
      identity: decoder.readIdentity(),
      connectedAt: decoder.readU64(),
      name: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'identity': identity.toJson(),
      'connectedAt': connectedAt.toInt(),
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConnectedUser &&
            connectionId == other.connectionId &&
            identity == other.identity &&
            connectedAt == other.connectedAt &&
            name == other.name;
  }

  @override
  int get hashCode {
    return Object.hashAll([connectionId, identity, connectedAt, name]);
  }

  @override
  String toString() {
    return 'ConnectedUser(connectionId: $connectionId, identity: $identity, connectedAt: $connectedAt, name: $name)';
  }

  ConnectedUser copyWith({
    String? connectionId,
    Identity? identity,
    Int64? connectedAt,
    String? name,
  }) {
    return ConnectedUser(
      connectionId: connectionId ?? this.connectionId,
      identity: identity ?? this.identity,
      connectedAt: connectedAt ?? this.connectedAt,
      name: name ?? this.name,
    );
  }
}

class ConnectedUserDecoder extends RowDecoder<ConnectedUser> {
  @override
  ConnectedUser decode(BsatnDecoder decoder) {
    return ConnectedUser.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(ConnectedUser row) {
    return row.connectionId;
  }

  @override
  Map<String, dynamic>? toJson(ConnectedUser row) {
    return row.toJson();
  }

  @override
  ConnectedUser? fromJson(Map<String, dynamic> json) {
    return ConnectedUser.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
