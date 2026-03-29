import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/space_channel/session_activity_event.dart';
import '../../services/space_channel/space_channel_event.dart';
import '../../services/space_channel/space_channel_service.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SpaceChannelService _spaceChannel;
  StreamSubscription<SessionActivityEvent>? _activitySub;
  StreamSubscription<SpaceChannelEvent>? _msgSub;

  SessionBloc(this._spaceChannel) : super(const SessionState()) {
    on<SessionConnected>(_onSessionConnected);
    on<SessionDisconnected>(_onSessionDisconnected);
    on<SessionToolEventReceived>(_onToolEventReceived);
    on<SessionStatusChanged>(_onStatusChanged);
    on<SessionMessageReceived>(_onMessageReceived);

    _activitySub = _spaceChannel.sessionActivity.listen((activity) {
      switch (activity.type) {
        case SessionActivityType.connected:
          final e = activity.sessionEvent!;
          add(SessionConnected(
            session: e.session,
            project: e.project ?? '',
            task: e.task ?? '',
          ));
        case SessionActivityType.disconnected:
          add(SessionDisconnected(activity.session));
        case SessionActivityType.toolUse:
          add(SessionToolEventReceived(activity.toolEvent!));
        case SessionActivityType.status:
          final s = activity.statusEvent!;
          final activityState = switch (s.state) {
            'thinking' => SessionActivityState.thinking,
            _ => SessionActivityState.idle,
          };
          add(SessionStatusChanged(session: s.session, activityState: activityState));
      }
    });

    _msgSub = _spaceChannel.eventStream.listen((e) {
      if (e.session != null && e.session!.isNotEmpty) {
        add(SessionMessageReceived(e.session!));
      }
    });
  }

  SessionInfo _ensureSession(String session) {
    return state.sessions[session] ?? SessionInfo(
      session: session,
      project: '',
      task: '',
      connectedAt: DateTime.now(),
      lastActivity: DateTime.now(),
    );
  }

  void _onSessionConnected(SessionConnected event, Emitter<SessionState> emit) {
    final now = DateTime.now();
    emit(state.copyWith(
      sessions: {
        ...state.sessions,
        event.session: SessionInfo(
          session: event.session,
          project: event.project,
          task: event.task,
          connectedAt: now,
          lastActivity: now,
        ),
      },
    ));
  }

  void _onSessionDisconnected(SessionDisconnected event, Emitter<SessionState> emit) {
    final updated = Map<String, SessionInfo>.from(state.sessions)..remove(event.session);
    emit(state.copyWith(sessions: updated));
  }

  void _onToolEventReceived(SessionToolEventReceived event, Emitter<SessionState> emit) {
    final toolEvent = event.toolEvent;
    final info = _ensureSession(toolEvent.session);

    final updatedEvents = [...info.recentToolEvents, toolEvent];
    final trimmed = updatedEvents.length > 10
        ? updatedEvents.sublist(updatedEvents.length - 10)
        : updatedEvents;

    emit(state.copyWith(
      sessions: {
        ...state.sessions,
        toolEvent.session: info.copyWith(
          lastActivity: DateTime.now(),
          recentToolEvents: trimmed,
          activityState: SessionActivityState.toolUse,
        ),
      },
    ));
  }

  void _onStatusChanged(SessionStatusChanged event, Emitter<SessionState> emit) {
    final info = _ensureSession(event.session);
    emit(state.copyWith(
      sessions: {
        ...state.sessions,
        event.session: info.copyWith(
          lastActivity: DateTime.now(),
          activityState: event.activityState,
        ),
      },
    ));
  }

  void _onMessageReceived(SessionMessageReceived event, Emitter<SessionState> emit) {
    if (state.sessions.containsKey(event.session)) return;
    final now = DateTime.now();
    emit(state.copyWith(
      sessions: {
        ...state.sessions,
        event.session: SessionInfo(
          session: event.session,
          project: '',
          task: '',
          connectedAt: now,
          lastActivity: now,
        ),
      },
    ));
  }

  @override
  Future<void> close() {
    _activitySub?.cancel();
    _msgSub?.cancel();
    return super.close();
  }
}
