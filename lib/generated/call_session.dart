// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import 'call_state.dart';

class CallSession {
  final Int64 sessionId;
  final Identity caller;
  final Identity callee;
  final CallState state;

  CallSession({
    required this.sessionId,
    required this.caller,
    required this.callee,
    required this.state,
  });

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

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      sessionId: Int64(json['sessionId'] ?? 0),
      caller: Identity.fromJson(json['caller'] ?? ''),
      callee: Identity.fromJson(json['callee'] ?? ''),
      state: CallState.fromJson(Map<String, dynamic>.from(json['state'] ?? {})),
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
  Map<String, dynamic>? toJson(CallSession row) => row.toJson();

  @override
  CallSession? fromJson(Map<String, dynamic> json) => CallSession.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
