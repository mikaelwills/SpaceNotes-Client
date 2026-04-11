// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/codegen.dart';
import 'call_state.dart';

class CallSession {
  CallSession({
    required this.sessionId,
    required this.caller,
    required this.callee,
    required this.state,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      sessionId: Int64(json['sessionId'] ?? 0),
      caller: Identity.fromJson(json['caller'] ?? ''),
      callee: Identity.fromJson(json['callee'] ?? ''),
      state: CallState.fromJson(Map<String, dynamic>.from(json['state'] ?? {})),
    );
  }

  final Int64 sessionId;

  final Identity caller;

  final Identity callee;

  final CallState state;

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(sessionId);
    encoder.writeIdentity(caller);
    encoder.writeIdentity(callee);
    state.encode(encoder);
  }

  static CallSession decodeBsatn(BsatnDecoder decoder) {
    return CallSession(
      sessionId: decoder.readU64(),
      caller: decoder.readIdentity(),
      callee: decoder.readIdentity(),
      state: CallState.decode(decoder),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId.toInt(),
      'caller': caller.toJson(),
      'callee': callee.toJson(),
      'state': state.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CallSession &&
            sessionId == other.sessionId &&
            caller == other.caller &&
            callee == other.callee &&
            state == other.state;
  }

  @override
  int get hashCode {
    return Object.hash(sessionId, caller, callee, state);
  }

  @override
  String toString() {
    return 'CallSession(sessionId: $sessionId, caller: $caller, callee: $callee, state: $state)';
  }

  CallSession copyWith({
    Int64? sessionId,
    Identity? caller,
    Identity? callee,
    CallState? state,
  }) {
    return CallSession(
      sessionId: sessionId ?? this.sessionId,
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
    return row.sessionId;
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
