import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/session_event.dart' as model;
import '../../models/tool_event.dart';
import '../../services/space_channel_service.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SpaceChannelService _spaceChannel;
  StreamSubscription<model.SessionEvent>? _sessionSub;
  StreamSubscription<ToolEvent>? _toolSub;
  StreamSubscription<StatusEvent>? _statusSub;

  SessionBloc(this._spaceChannel) : super(const SessionState()) {
    on<SessionConnected>(_onSessionConnected);
    on<SessionDisconnected>(_onSessionDisconnected);
    on<SessionToolEventReceived>(_onToolEventReceived);
    on<SessionStatusChanged>(_onStatusChanged);

    _sessionSub = _spaceChannel.sessionEvents.listen((event) {
      if (event.isConnected) {
        add(SessionConnected(
          session: event.session,
          project: event.project ?? '',
          task: event.task ?? '',
        ));
      } else if (event.isDisconnected) {
        add(SessionDisconnected(event.session));
      }
    });

    _toolSub = _spaceChannel.toolEvents.listen((event) {
      add(SessionToolEventReceived(event));
    });

    _statusSub = _spaceChannel.statusEvents.listen((event) {
      final activityState = switch (event.state) {
        'thinking' => SessionActivityState.thinking,
        'idle' => SessionActivityState.idle,
        _ => SessionActivityState.idle,
      };
      add(SessionStatusChanged(session: event.session, activityState: activityState));
    });
  }

  void _onSessionConnected(SessionConnected event, Emitter<SessionState> emit) {
    final now = DateTime.now();
    final info = SessionInfo(
      session: event.session,
      project: event.project,
      task: event.task,
      connectedAt: now,
      lastActivity: now,
    );
    emit(state.copyWith(
      sessions: {...state.sessions, event.session: info},
    ));
  }

  void _onSessionDisconnected(SessionDisconnected event, Emitter<SessionState> emit) {
    final updated = Map<String, SessionInfo>.from(state.sessions)..remove(event.session);
    emit(state.copyWith(sessions: updated));
  }

  void _onToolEventReceived(SessionToolEventReceived event, Emitter<SessionState> emit) {
    final toolEvent = event.toolEvent;
    final info = state.sessions[toolEvent.session];
    if (info == null) return;

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
    final info = state.sessions[event.session];
    if (info == null) return;

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

  @override
  Future<void> close() {
    _sessionSub?.cancel();
    _toolSub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }
}
