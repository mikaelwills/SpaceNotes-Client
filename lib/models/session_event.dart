import 'package:equatable/equatable.dart';

class SessionEvent extends Equatable {
  final String action;
  final String session;
  final String? project;
  final String? task;

  const SessionEvent({
    required this.action,
    required this.session,
    this.project,
    this.task,
  });

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      action: json['action'] ?? '',
      session: json['session'] ?? '',
      project: json['project'],
      task: json['task'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'session': session,
      if (project != null) 'project': project,
      if (task != null) 'task': task,
    };
  }

  bool get isConnected => action == 'connected';
  bool get isDisconnected => action == 'disconnected';

  @override
  List<Object?> get props => [action, session, project, task];
}
