import 'package:equatable/equatable.dart';

class ToolEvent extends Equatable {
  final String toolName;
  final String inputSummary;
  final DateTime timestamp;

  const ToolEvent({
    required this.toolName,
    required this.inputSummary,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [toolName, inputSummary, timestamp];
}

class WorkerInfo extends Equatable {
  final String session;
  final String project;
  final String task;
  final bool isMaster;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final List<ToolEvent> recentToolEvents;

  const WorkerInfo({
    required this.session,
    required this.project,
    required this.task,
    required this.isMaster,
    required this.connectedAt,
    required this.lastActivity,
    this.recentToolEvents = const [],
  });

  WorkerInfo copyWith({
    DateTime? lastActivity,
    List<ToolEvent>? recentToolEvents,
  }) {
    return WorkerInfo(
      session: session,
      project: project,
      task: task,
      isMaster: isMaster,
      connectedAt: connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      recentToolEvents: recentToolEvents ?? this.recentToolEvents,
    );
  }

  @override
  List<Object?> get props => [
        session,
        project,
        task,
        isMaster,
        connectedAt,
        lastActivity,
        recentToolEvents,
      ];
}

class WorkerState extends Equatable {
  final Map<String, WorkerInfo> workers;

  const WorkerState({this.workers = const {}});

  WorkerState copyWith({Map<String, WorkerInfo>? workers}) {
    return WorkerState(workers: workers ?? this.workers);
  }

  @override
  List<Object?> get props => [workers];
}
