import 'package:equatable/equatable.dart';
import '../../models/tool_event.dart';

enum SessionActivityState { idle, thinking, toolUse }

class SessionInfo extends Equatable {
  final String session;
  final String project;
  final String task;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final List<ToolEvent> recentToolEvents;
  final SessionActivityState activityState;

  const SessionInfo({
    required this.session,
    required this.project,
    required this.task,
    required this.connectedAt,
    required this.lastActivity,
    this.recentToolEvents = const [],
    this.activityState = SessionActivityState.idle,
  });

  SessionInfo copyWith({
    DateTime? lastActivity,
    List<ToolEvent>? recentToolEvents,
    SessionActivityState? activityState,
  }) {
    return SessionInfo(
      session: session,
      project: project,
      task: task,
      connectedAt: connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      recentToolEvents: recentToolEvents ?? this.recentToolEvents,
      activityState: activityState ?? this.activityState,
    );
  }

  @override
  List<Object?> get props => [
        session,
        project,
        task,
        connectedAt,
        lastActivity,
        recentToolEvents,
        activityState,
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
