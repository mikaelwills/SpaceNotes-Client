// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/codegen.dart';

sealed class CallState {
  const CallState();

  factory CallState.decode(BsatnDecoder decoder) {
    final tag = decoder.readU8();
    switch (tag) {
      case 0:
        return CallStateRinging.decode(decoder);
      case 1:
        return CallStateActive.decode(decoder);
      case 2:
        return CallStateEnded.decode(decoder);
      default:
        throw Exception('Unknown CallState variant: $tag');
    }
  }

  factory CallState.fromJson(Map<String, dynamic> json) {
    final type = json['type'] ?? '';
    switch (type) {
      case 'Ringing':
        return CallStateRinging.fromJson(json);
      case 'Active':
        return CallStateActive.fromJson(json);
      case 'Ended':
        return CallStateEnded.fromJson(json);
      default:
        throw Exception('Unknown CallState variant: $type');
    }
  }

  void encode(BsatnEncoder encoder);
  Map<String, dynamic> toJson();
}

class CallStateRinging extends CallState {
  const CallStateRinging();

  factory CallStateRinging.decode(BsatnDecoder decoder) {
    return const CallStateRinging();
  }

  factory CallStateRinging.fromJson(Map<String, dynamic> json) {
    return const CallStateRinging();
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(0);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'Ringing'};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CallStateRinging;
  }

  @override
  int get hashCode {
    return runtimeType.hashCode;
  }

  @override
  String toString() {
    return 'CallStateRinging()';
  }
}

class CallStateActive extends CallState {
  const CallStateActive();

  factory CallStateActive.decode(BsatnDecoder decoder) {
    return const CallStateActive();
  }

  factory CallStateActive.fromJson(Map<String, dynamic> json) {
    return const CallStateActive();
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(1);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'Active'};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CallStateActive;
  }

  @override
  int get hashCode {
    return runtimeType.hashCode;
  }

  @override
  String toString() {
    return 'CallStateActive()';
  }
}

class CallStateEnded extends CallState {
  const CallStateEnded();

  factory CallStateEnded.decode(BsatnDecoder decoder) {
    return const CallStateEnded();
  }

  factory CallStateEnded.fromJson(Map<String, dynamic> json) {
    return const CallStateEnded();
  }

  @override
  void encode(BsatnEncoder encoder) {
    encoder.writeU8(2);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'Ended'};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CallStateEnded;
  }

  @override
  int get hashCode {
    return runtimeType.hashCode;
  }

  @override
  String toString() {
    return 'CallStateEnded()';
  }
}
