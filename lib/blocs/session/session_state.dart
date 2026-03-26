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

class SessionInfo extends Equatable {
  final String session;
  final String project;
  final String task;
  final bool isMaster;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final List<ToolEvent> recentToolEvents;

  const SessionInfo({
    required this.session,
    required this.project,
    required this.task,
    required this.isMaster,
    required this.connectedAt,
    required this.lastActivity,
    this.recentToolEvents = const [],
  });

  SessionInfo copyWith({
    DateTime? lastActivity,
    List<ToolEvent>? recentToolEvents,
  }) {
    return SessionInfo(
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

class SessionState extends Equatable {
  final Map<String, SessionInfo> sessions;

  const SessionState({this.sessions = const {}});

  SessionState copyWith({Map<String, SessionInfo>? sessions}) {
    return SessionState(sessions: sessions ?? this.sessions);
  }

  @override
  List<Object?> get props => [sessions];
}
