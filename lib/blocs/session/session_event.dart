import 'package:equatable/equatable.dart';
import '../../models/session.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object> get props => [];
}


class CreateSession extends SessionEvent {
  final String? agent;

  const CreateSession({this.agent});

  @override
  List<Object> get props => agent != null ? [agent!] : [];
}


class SendMessage extends SessionEvent {
  final String sessionId;
  final String message;
  final String? agent;

  const SendMessage({required this.sessionId, required this.message, this.agent});

  @override
  List<Object> get props => [sessionId, message, if (agent != null) agent!];
}

class CancelSessionOperation extends SessionEvent {
  final String sessionId;

  const CancelSessionOperation(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class SessionUpdated extends SessionEvent {
  final Session session;

  const SessionUpdated(this.session);

  @override
  List<Object> get props => [session];
}

class LoadStoredSession extends SessionEvent {}

class ValidateSession extends SessionEvent {
  final String sessionId;

  const ValidateSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class SetCurrentSession extends SessionEvent {
  final String sessionId;

  const SetCurrentSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}