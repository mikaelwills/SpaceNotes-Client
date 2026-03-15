// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class ConnectedUser {
  final Identity identity;
  final Int64 connectedAt;
  final String name;

  ConnectedUser({
    required this.identity,
    required this.connectedAt,
    required this.name,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeIdentity(identity);
    encoder.writeU64(connectedAt);
    encoder.writeString(name);
  }

  static ConnectedUser decodeBsatn(BsatnDecoder decoder) {
    return ConnectedUser(
      identity: decoder.readIdentity(),
      connectedAt: decoder.readU64(),
      name: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toJson(),
      'connectedAt': connectedAt.toInt(),
      'name': name,
    };
  }

  factory ConnectedUser.fromJson(Map<String, dynamic> json) {
    return ConnectedUser(
      identity: Identity.fromJson(json['identity'] as String),
      connectedAt: Int64((json['connectedAt'] as int?) ?? 0),
      name: (json['name'] as String?) ?? '',
    );
  }

}

class ConnectedUserDecoder extends RowDecoder<ConnectedUser> {
  @override
  ConnectedUser decode(BsatnDecoder decoder) {
    return ConnectedUser.decodeBsatn(decoder);
  }

  @override
  Identity? getPrimaryKey(ConnectedUser row) {
    return row.identity;
  }

  @override
  Map<String, dynamic>? toJson(ConnectedUser row) => row.toJson();

  @override
  ConnectedUser? fromJson(Map<String, dynamic> json) => ConnectedUser.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
