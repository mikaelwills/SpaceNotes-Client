import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';

abstract class SessionChatEvent extends Equatable {
  const SessionChatEvent();

  @override
  List<Object?> get props => [];
}

class SessionChatMessageReceived extends SessionChatEvent {
  final String sessionId;
  final SpaceMessage message;

  const SessionChatMessageReceived(this.sessionId, this.message);

  @override
  List<Object?> get props => [sessionId, message];
}

class SessionChatSendMessage extends SessionChatEvent {
  final String sessionId;
  final String text;

  const SessionChatSendMessage(this.sessionId, this.text);

  @override
  List<Object?> get props => [sessionId, text];
}

class SessionChatSessionRemoved extends SessionChatEvent {
  final String sessionId;

  const SessionChatSessionRemoved(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}
