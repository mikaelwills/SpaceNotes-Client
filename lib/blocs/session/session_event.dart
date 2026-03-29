import 'package:equatable/equatable.dart';
import '../../models/tool_event.dart';
import 'session_state.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

class SessionConnected extends SessionEvent {
  final String session;
  final String project;
  final String task;

  const SessionConnected({
    required this.session,
    required this.project,
    required this.task,
  });

  @override
  List<Object?> get props => [session, project, task];
}

class SessionDisconnected extends SessionEvent {
  final String session;

  const SessionDisconnected(this.session);

  @override
  List<Object?> get props => [session];
}

class SessionToolEventReceived extends SessionEvent {
  final ToolEvent toolEvent;

  const SessionToolEventReceived(this.toolEvent);

  @override
  List<Object?> get props => [toolEvent];
}

class SessionStatusChanged extends SessionEvent {
  final String session;
  final SessionActivityState activityState;

  const SessionStatusChanged({required this.session, required this.activityState});

  @override
  List<Object?> get props => [session, activityState];
}

class SessionMessageReceived extends SessionEvent {
  final String session;

  const SessionMessageReceived(this.session);

  @override
  List<Object?> get props => [session];
}
