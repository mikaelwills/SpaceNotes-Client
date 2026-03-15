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

    void emit() {
      final myIdentity = client.identity;
      if (myIdentity == null) {
        controller.add(null);
        return;
      }
      final allSessions = client.callSession.iter().toList();
      debugLogger.info('CALL_SESSION', 'All sessions: ${allSessions.map((s) => 'id=${s.sessionId} state=${s.state.runtimeType}').toList()}');
      final sessions = allSessions.where((s) {
        final isParticipant = s.caller == myIdentity || s.callee == myIdentity;
        final isActive = s.state is! CallStateEnded;
        return isParticipant && isActive;
      }).toList();
      debugLogger.info('CALL_SESSION', 'Active for me: ${sessions.length}');
      controller.add(sessions.isEmpty ? null : sessions.first);
    }

    final subs = <StreamSubscription>[];
    subs.add(client.callSession.insertEventStream.listen((_) {
      debugLogger.info('CALL_SESSION', 'Insert event received');
      emit();
    }));
    subs.add(client.callSession.updateEventStream.listen((_) {
      debugLogger.info('CALL_SESSION', 'Update event received');
      emit();
    }));
    subs.add(client.callSession.deleteEventStream.listen((_) {
      debugLogger.info('CALL_SESSION', 'Delete event received');
      emit();
    }));

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
  debugLogger.info('INCOMING_CALL', 'Provider created');
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().distinct().asyncExpand((client) {
    if (client == null) {
      debugLogger.info('INCOMING_CALL', 'Client is null');
      return Stream.value(null);
    }

    debugLogger.info('INCOMING_CALL', 'Client ready, setting up listeners');
    final controller = StreamController<CallSession?>();

    void emit() {
      final myIdentity = client.identity;
      if (myIdentity == null) {
        debugLogger.info('INCOMING_CALL', 'Identity is null');
        controller.add(null);
        return;
      }
      final allSessions = client.callSession.iter().toList();
      final ringing = allSessions.where((s) {
        return s.callee == myIdentity && s.state is CallStateRinging;
      }).toList();
      debugLogger.info('INCOMING_CALL', 'Total sessions=${allSessions.length}, ringing for me=${ringing.length}');
      controller.add(ringing.isEmpty ? null : ringing.first);
    }

    final subs = <StreamSubscription>[];
    subs.add(client.callSession.insertEventStream.listen((_) {
      debugLogger.info('INCOMING_CALL', 'Insert event');
      emit();
    }));
    subs.add(client.callSession.updateEventStream.listen((_) {
      debugLogger.info('INCOMING_CALL', 'Update event');
      emit();
    }));
    subs.add(client.callSession.deleteEventStream.listen((_) {
      debugLogger.info('INCOMING_CALL', 'Delete event');
      emit();
    }));

    emit();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) emit();
    });

    controller.onCancel = () {
      debugLogger.info('INCOMING_CALL', 'Provider cancelled');
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  });
});

final remoteVideoFrameProvider = StreamProvider.autoDispose<Uint8List?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchClient().asyncExpand((client) {
    if (client == null) return Stream.value(null);

    final controller = StreamController<Uint8List?>();
    final myIdentity = client.identity;
    debugLogger.info('VIDEO_RX', 'Listening for video frames, myIdentity=${myIdentity?.toAbbreviated}');

    int frameCount = 0;
    final sub = client.videoFrame.insertEventStream.listen((event) {
      final frame = event.row;
      frameCount++;
      if (frameCount <= 5 || frameCount % 30 == 0) {
        debugLogger.info('VIDEO_RX', 'Frame #$frameCount from=${frame.from.toAbbreviated}, mine=${myIdentity?.toAbbreviated}, isRemote=${frame.from != myIdentity}, size=${frame.jpeg.length}');
      }
      if (myIdentity != null && frame.from != myIdentity) {
        ref.read(callServiceProvider).videoStats?.recordReceive(seq: frame.seq, sizeBytes: frame.jpeg.length);
        controller.add(Uint8List.fromList(frame.jpeg));
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
