// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class ChannelConfig {
  ChannelConfig({
    required this.id,
    required this.a2aEnabled,
  });

  factory ChannelConfig.fromJson(Map<String, dynamic> json) {
    return ChannelConfig(
      id: json['id'] ?? 0,
      a2aEnabled: json['a2aEnabled'] ?? false,
    );
  }

  final int id;

  final bool a2aEnabled;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU32(id);
    encoder.writeBool(a2aEnabled);
  }

  static ChannelConfig decodeBsatn(BsatnDecoder decoder) {
    return ChannelConfig(
      id: decoder.readU32(),
      a2aEnabled: decoder.readBool(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'a2aEnabled': a2aEnabled,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelConfig &&
            id == other.id &&
            a2aEnabled == other.a2aEnabled;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, a2aEnabled]);
  }

  @override
  String toString() {
    return 'ChannelConfig(id: $id, a2aEnabled: $a2aEnabled)';
  }

  ChannelConfig copyWith({
    int? id,
    bool? a2aEnabled,
  }) {
    return ChannelConfig(
      id: id ?? this.id,
      a2aEnabled: a2aEnabled ?? this.a2aEnabled,
    );
  }
}

class ChannelConfigDecoder extends RowDecoder<ChannelConfig> {
  @override
  ChannelConfig decode(BsatnDecoder decoder) {
    return ChannelConfig.decodeBsatn(decoder);
  }

  @override
  int? getPrimaryKey(ChannelConfig row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(ChannelConfig row) {
    return row.toJson();
  }

  @override
  ChannelConfig? fromJson(Map<String, dynamic> json) {
    return ChannelConfig.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
