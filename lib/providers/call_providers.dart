import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/call_session.dart';
import '../generated/call_state.dart';
import '../services/call_service.dart';
import '../services/debug_logger.dart';
import 'notes_providers.dart';

final activeCallSessionProvider = StreamProvider<CallSession?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().distinct().asyncExpand((client) {
    if (client == null) return Stream.value(null);

    final controller = StreamController<CallSession?>();

    CallSession? lastEmitted;

    void emit() {
      final myIdentity = client.identity;
      if (myIdentity == null) {
        controller.add(null);
        return;
      }
      final sessions = client.callSession.iter().where((s) {
        final isParticipant = s.caller == myIdentity || s.callee == myIdentity;
        final isActive = s.state is! CallStateEnded;
        return isParticipant && isActive;
      }).toList();
      final session = sessions.isEmpty ? null : sessions.first;
      if (session?.sessionId != lastEmitted?.sessionId || session?.state.runtimeType != lastEmitted?.state.runtimeType) {
        debugLogger.info('CALL_SESSION', 'Active session: ${session != null ? "id=${session.sessionId} state=${session.state.runtimeType}" : "none"}');
        lastEmitted = session;
      }
      controller.add(session);
    }

    final subs = <StreamSubscription>[];
    subs.add(client.callSession.insertEventStream.listen((_) => emit()));
    subs.add(client.callSession.updateEventStream.listen((_) => emit()));
    subs.add(client.callSession.deleteEventStream.listen((_) => emit()));

    emit();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) emit();
    });

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  });
});

final incomingCallProvider = StreamProvider<CallSession?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().distinct().asyncExpand((client) {
    if (client == null) return Stream.value(null);

    final controller = StreamController<CallSession?>();
    bool hadIncoming = false;

    void emit() {
      final myIdentity = client.identity;
      if (myIdentity == null) {
        controller.add(null);
        return;
      }
      final ringing = client.callSession.iter().where((s) {
        return s.callee == myIdentity && s.state is CallStateRinging;
      }).toList();
      final hasIncoming = ringing.isNotEmpty;
      if (hasIncoming != hadIncoming) {
        debugLogger.info('INCOMING_CALL', hasIncoming ? 'Ringing: id=${ringing.first.sessionId}' : 'No incoming calls');
        hadIncoming = hasIncoming;
      }
      controller.add(ringing.isEmpty ? null : ringing.first);
    }

    final subs = <StreamSubscription>[];
    subs.add(client.callSession.insertEventStream.listen((_) => emit()));
    subs.add(client.callSession.updateEventStream.listen((_) => emit()));
    subs.add(client.callSession.deleteEventStream.listen((_) => emit()));

    emit();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) emit();
    });

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  });
});

class ReceivedVideoFrame {
  final Uint8List data;
  final int codec;
  final bool isKeyframe;
  final int seq;

  ReceivedVideoFrame({required this.data, required this.codec, required this.isKeyframe, required this.seq});
}

final remoteVideoFrameProvider = StreamProvider.autoDispose<ReceivedVideoFrame?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().asyncExpand((client) {
    if (client == null) return Stream.value(null);

    final controller = StreamController<ReceivedVideoFrame?>();
    final myIdentity = client.identity;
    debugLogger.info('VIDEO_RX', 'Listening for video frames');

    int frameCount = 0;
    bool emitting = false;
    ReceivedVideoFrame? pendingFrame;

    void tryEmit(ReceivedVideoFrame frame) {
      if (emitting) {
        pendingFrame = frame;
        return;
      }
      emitting = true;
      controller.add(frame);
      Future.microtask(() {
        emitting = false;
        if (pendingFrame != null) {
          final next = pendingFrame!;
          pendingFrame = null;
          tryEmit(next);
        }
      });
    }

    final sub = client.videoFrame.insertEventStream.listen((event) {
      final frame = event.row;
      frameCount++;
      if (frameCount <= 3 || frameCount % 300 == 0) {
        final codecName = frame.codec == 0 ? 'JPEG' : 'H264';
        debugLogger.info('VIDEO_RX', 'Frame #$frameCount, codec=$codecName, keyframe=${frame.isKeyframe}, size=${frame.data.length ~/ 1024}KB');
      }
      if (myIdentity != null && frame.from != myIdentity) {
        ref.read(callServiceProvider).videoStats?.recordReceive(seq: frame.seq, sizeBytes: frame.data.length);
        tryEmit(ReceivedVideoFrame(data: Uint8List.fromList(frame.data), codec: frame.codec, isKeyframe: frame.isKeyframe, seq: frame.seq));
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  });
});

final remoteAudioFrameProvider = StreamProvider.autoDispose<Uint8List?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().asyncExpand((client) {
    if (client == null) return Stream.value(null);

    final controller = StreamController<Uint8List?>();
    final myIdentity = client.identity;

    final sub = client.audioFrame.insertEventStream.listen((event) {
      final frame = event.row;
      if (myIdentity != null && frame.from != myIdentity) {
        controller.add(Uint8List.fromList(frame.pcm));
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  });
});

final myIdentityProvider = Provider<Identity?>((ref) {
  final clientAsync = ref.watch(spacetimeClientProvider);
  return clientAsync.valueOrNull?.identity;
});

final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService();
  ref.onDispose(() => service.dispose());
  return service;
});
