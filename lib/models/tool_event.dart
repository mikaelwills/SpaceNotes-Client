import 'package:equatable/equatable.dart';

class ToolEvent extends Equatable {
  final String session;
  final String project;
  final String task;
  final String tool;
  final Map<String, dynamic> input;
  final DateTime timestamp;

  const ToolEvent({
    required this.session,
    required this.project,
    required this.task,
    required this.tool,
    required this.input,
    required this.timestamp,
  });

  factory ToolEvent.fromJson(Map<String, dynamic> json) {
    final ts = json['ts'];
    return ToolEvent(
      session: json['session'] ?? '',
      project: json['project'] ?? '',
      task: json['task'] ?? '',
      tool: json['tool'] ?? '',
      input: json['input'] ?? {},
      timestamp: ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session,
      'project': project,
      'task': task,
      'tool': tool,
      'input': input,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => [session, project, task, tool, input, timestamp];
}
