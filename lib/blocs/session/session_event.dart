import 'package:equatable/equatable.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

class SessionConnected extends SessionEvent {
  final String session;
  final String project;
  final String task;
  final bool isMaster;

  const SessionConnected({
    required this.session,
    required this.project,
    required this.task,
    required this.isMaster,
  });

  @override
  List<Object?> get props => [session, project, task, isMaster];
}

class SessionDisconnected extends SessionEvent {
  final String session;

  const SessionDisconnected(this.session);

  @override
  List<Object?> get props => [session];
}

class SessionToolEventReceived extends SessionEvent {
  final String session;
  final String toolName;
  final String inputSummary;

  const SessionToolEventReceived({
    required this.session,
    required this.toolName,
    required this.inputSummary,
  });

  @override
  List<Object?> get props => [session, toolName, inputSummary];
}
