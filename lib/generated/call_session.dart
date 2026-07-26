// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';
import 'call_state.dart';

class CallSession {
  CallSession({
    required this.callId,
    required this.caller,
    required this.callee,
    required this.state,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      callId: Int64(json['callId'] ?? 0),
      caller: Identity.fromJson(json['caller'] ?? ''),
      callee: Identity.fromJson(json['callee'] ?? ''),
      state: CallState.fromJson(Map<String, dynamic>.from(json['state'] ?? {})),
    );
  }

  final Int64 callId;

  final Identity caller;

  final Identity callee;

  final CallState state;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(callId);
    encoder.writeIdentity(caller);
    encoder.writeIdentity(callee);
    state.encodeBsatn(encoder);
  }

  static CallSession decodeBsatn(BsatnDecoder decoder) {
    return CallSession(
      callId: decoder.readU64(),
      caller: decoder.readIdentity(),
      callee: decoder.readIdentity(),
      state: CallState.decodeBsatn(decoder),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId.toInt(),
      'caller': caller.toJson(),
      'callee': callee.toJson(),
      'state': state.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CallSession &&
            callId == other.callId &&
            caller == other.caller &&
            callee == other.callee &&
            state == other.state;
  }

  @override
  int get hashCode {
    return Object.hashAll([callId, caller, callee, state]);
  }

  @override
  String toString() {
    return 'CallSession(callId: $callId, caller: $caller, callee: $callee, state: $state)';
  }

  CallSession copyWith({
    Int64? callId,
    Identity? caller,
    Identity? callee,
    CallState? state,
  }) {
    return CallSession(
      callId: callId ?? this.callId,
      caller: caller ?? this.caller,
      callee: callee ?? this.callee,
      state: state ?? this.state,
    );
  }
}

class CallSessionDecoder extends RowDecoder<CallSession> {
  @override
  CallSession decode(BsatnDecoder decoder) {
    return CallSession.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(CallSession row) {
    return row.callId;
  }

  @override
  Map<String, dynamic>? toJson(CallSession row) {
    return row.toJson();
  }

  @override
  CallSession? fromJson(Map<String, dynamic> json) {
    return CallSession.fromJson(json);
  }

  @override
  bool get supportsJsonSerialization {
    return true;
  }
}
