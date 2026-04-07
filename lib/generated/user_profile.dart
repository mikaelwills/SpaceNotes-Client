// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

class UserProfile {
  UserProfile({
    required this.identity,
    required this.name,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      identity: Identity.fromJson(json['identity'] ?? ''),
      name: json['name'] ?? '',
    );
  }

  final Identity identity;

  final String name;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeIdentity(identity);
    encoder.writeString(name);
  }

  static UserProfile decodeBsatn(BsatnDecoder decoder) {
    return UserProfile(
      identity: decoder.readIdentity(),
      name: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toJson(),
      'name': name,
    };
  }
}

class UserProfileDecoder extends RowDecoder<UserProfile> {
  @override
  UserProfile decode(BsatnDecoder decoder) {
    return UserProfile.decodeBsatn(decoder);
  }

  @override
  Identity? getPrimaryKey(UserProfile row) {
    return row.identity;
  }

  @override
  Map<String, dynamic>? toJson(UserProfile row) {
    return row.toJson();
  }

  @override
  UserProfile? fromJson(Map<String, dynamic> json) {
    return UserProfile.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
