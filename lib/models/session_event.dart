import 'package:equatable/equatable.dart';

String composeSessionKey(String session, String host) {
  if (host.isEmpty) return session;
  return '$session@$host';
}

({String base, String host}) splitSessionKey(String key) {
  final idx = key.indexOf('@');
  if (idx < 0) return (base: key, host: '');
  return (base: key.substring(0, idx), host: key.substring(idx + 1));
}

class SessionEvent extends Equatable {
  final String action;
  final String session;
  final String? task;
  final String host;

  const SessionEvent({
    required this.action,
    required this.session,
    this.task,
    this.host = '',
  });

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    final String baseSession = json['session'] ?? '';
    final String host = json['host'] ?? '';
    return SessionEvent(
      action: json['action'] ?? '',
      session: composeSessionKey(baseSession, host),
      task: json['task'],
      host: host,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'session': session,
      if (task != null) 'task': task,
      if (host.isNotEmpty) 'host': host,
    };
  }

  bool get isConnected => action == 'connected';
  bool get isDisconnected => action == 'disconnected';

  @override
  List<Object?> get props => [action, session, task, host];
}
