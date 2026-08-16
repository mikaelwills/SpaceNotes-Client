// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class ChannelConfig {
  ChannelConfig({
    required this.id,
    required this.a2aEnabled,
    required this.a2aCooldownSecs,
    required this.a2aHourlyLimit,
    required this.a2aMaxHops,
  });

  factory ChannelConfig.fromJson(Map<String, dynamic> json) {
    return ChannelConfig(
      id: json['id'] ?? 0,
      a2aEnabled: json['a2aEnabled'] ?? false,
      a2aCooldownSecs: json['a2aCooldownSecs'] ?? 0,
      a2aHourlyLimit: json['a2aHourlyLimit'] ?? 0,
      a2aMaxHops: json['a2aMaxHops'] ?? 0,
    );
  }

  final int id;

  final bool a2aEnabled;

  final int a2aCooldownSecs;

  final int a2aHourlyLimit;

  final int a2aMaxHops;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU32(id);
    encoder.writeBool(a2aEnabled);
    encoder.writeU32(a2aCooldownSecs);
    encoder.writeU32(a2aHourlyLimit);
    encoder.writeU32(a2aMaxHops);
  }

  static ChannelConfig decodeBsatn(BsatnDecoder decoder) {
    return ChannelConfig(
      id: decoder.readU32(),
      a2aEnabled: decoder.readBool(),
      a2aCooldownSecs: decoder.readU32(),
      a2aHourlyLimit: decoder.readU32(),
      a2aMaxHops: decoder.readU32(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'a2aEnabled': a2aEnabled,
      'a2aCooldownSecs': a2aCooldownSecs,
      'a2aHourlyLimit': a2aHourlyLimit,
      'a2aMaxHops': a2aMaxHops,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelConfig &&
            id == other.id &&
            a2aEnabled == other.a2aEnabled &&
            a2aCooldownSecs == other.a2aCooldownSecs &&
            a2aHourlyLimit == other.a2aHourlyLimit &&
            a2aMaxHops == other.a2aMaxHops;
  }

  @override
  int get hashCode {
    return Object.hashAll(
        [id, a2aEnabled, a2aCooldownSecs, a2aHourlyLimit, a2aMaxHops]);
  }

  @override
  String toString() {
    return 'ChannelConfig(id: $id, a2aEnabled: $a2aEnabled, a2aCooldownSecs: $a2aCooldownSecs, a2aHourlyLimit: $a2aHourlyLimit, a2aMaxHops: $a2aMaxHops)';
  }

  ChannelConfig copyWith({
    int? id,
    bool? a2aEnabled,
    int? a2aCooldownSecs,
    int? a2aHourlyLimit,
    int? a2aMaxHops,
  }) {
    return ChannelConfig(
      id: id ?? this.id,
      a2aEnabled: a2aEnabled ?? this.a2aEnabled,
      a2aCooldownSecs: a2aCooldownSecs ?? this.a2aCooldownSecs,
      a2aHourlyLimit: a2aHourlyLimit ?? this.a2aHourlyLimit,
      a2aMaxHops: a2aMaxHops ?? this.a2aMaxHops,
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
