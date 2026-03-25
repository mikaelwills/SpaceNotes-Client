import 'package:equatable/equatable.dart';

abstract class WorkerEvent extends Equatable {
  const WorkerEvent();

  @override
  List<Object?> get props => [];
}

class WorkerConnected extends WorkerEvent {
  final String session;
  final String project;
  final String task;
  final bool isMaster;

  const WorkerConnected({
    required this.session,
    required this.project,
    required this.task,
    required this.isMaster,
  });

  @override
  List<Object?> get props => [session, project, task, isMaster];
}

class WorkerDisconnected extends WorkerEvent {
  final String session;

  const WorkerDisconnected(this.session);

  @override
  List<Object?> get props => [session];
}

class WorkerToolEventReceived extends WorkerEvent {
  final String session;
  final String toolName;
  final String inputSummary;

  const WorkerToolEventReceived({
    required this.session,
    required this.toolName,
    required this.inputSummary,
  });

  @override
  List<Object?> get props => [session, toolName, inputSummary];
}
