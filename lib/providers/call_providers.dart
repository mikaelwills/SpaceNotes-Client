import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/call_session.dart';
import '../generated/call_state.dart';
import '../services/call_service.dart';
import '../services/debug_logger.dart';
import 'notes_providers.dart';

final activeCallSessionProvider = Provider<CallSession?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;

  final rows = watchListenable(ref, client.callSession.rows);
  final myIdentity = client.identity;
  if (myIdentity == null) return null;

  final session = rows.firstWhereOrNull((s) {
    final isParticipant = s.caller == myIdentity || s.callee == myIdentity;
    final isActive = s.state is! CallStateEnded;
    return isParticipant && isActive;
  });

  if (session != null) {
    debugLogger.info(
      'CALL_SESSION',
      'Active session: id=${session.sessionId} state=${session.state.runtimeType}',
    );
  }

  return session;
});

final incomingCallProvider = Provider<CallSession?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;

  final rows = watchListenable(ref, client.callSession.rows);
  final myIdentity = client.identity;
  if (myIdentity == null) return null;

  final ringing = rows.firstWhereOrNull(
    (s) => s.callee == myIdentity && s.state is CallStateRinging,
  );

  if (ringing != null) {
    debugLogger.info('INCOMING_CALL', 'Ringing: id=${ringing.sessionId}');
  }

  return ringing;
});

class ReceivedVideoFrame {
  final Uint8List data;
  final int codec;
  final bool isKeyframe;
  final int seq;

  ReceivedVideoFrame({
    required this.data,
    required this.codec,
    required this.isKeyframe,
    required this.seq,
  });
}

final remoteVideoFrameProvider =
    StreamProvider.autoDispose<ReceivedVideoFrame?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return Stream.value(null);

  final controller = StreamController<ReceivedVideoFrame?>();
  final myIdentity = client.identity;
  int frameCount = 0;

  void onBatch() {
    final batch = client.videoFrame.lastBatch.value;
    if (batch == null) return;
    for (final event in batch.inserts) {
      final frame = event.row;
      frameCount++;
      if (frameCount <= 3 || frameCount % 300 == 0) {
        final codecName = frame.codec == 0 ? 'JPEG' : 'H264';
        debugLogger.info(
          'VIDEO_RX',
          'Frame #$frameCount, codec=$codecName, keyframe=${frame.isKeyframe}, size=${frame.data.length ~/ 1024}KB',
        );
      }
      if (myIdentity != null && frame.from != myIdentity) {
        ref.read(callServiceProvider).videoStats?.recordReceive(
              seq: frame.seq,
              sizeBytes: frame.data.length,
            );
        controller.add(ReceivedVideoFrame(
          data: Uint8List.fromList(frame.data),
          codec: frame.codec,
          isKeyframe: frame.isKeyframe,
          seq: frame.seq,
        ));
      }
    }
  }

  debugLogger.info('VIDEO_RX', 'Listening for video frames');
  client.videoFrame.lastBatch.addListener(onBatch);
  ref.onDispose(() {
    client.videoFrame.lastBatch.removeListener(onBatch);
    controller.close();
  });

  return controller.stream;
});

final remoteAudioFrameProvider = StreamProvider.autoDispose<Uint8List?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return Stream.value(null);

  final controller = StreamController<Uint8List?>();
  final myIdentity = client.identity;

  void onBatch() {
    final batch = client.audioFrame.lastBatch.value;
    if (batch == null) return;
    for (final event in batch.inserts) {
      final frame = event.row;
      if (myIdentity != null && frame.from != myIdentity) {
        controller.add(Uint8List.fromList(frame.pcm));
      }
    }
  }

  client.audioFrame.lastBatch.addListener(onBatch);
  ref.onDispose(() {
    client.audioFrame.lastBatch.removeListener(onBatch);
    controller.close();
  });

  return controller.stream;
});

final myIdentityProvider = Provider<Identity?>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  return client?.identity;
});

final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService();
  ref.onDispose(() => service.dispose());
  return service;
});

extension _FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
