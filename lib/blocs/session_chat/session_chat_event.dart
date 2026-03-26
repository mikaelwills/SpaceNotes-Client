import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';

abstract class SessionChatEvent extends Equatable {
  const SessionChatEvent();

  @override
  List<Object?> get props => [];
}

class SessionChatStarted extends SessionChatEvent {
  final String sessionId;

  const SessionChatStarted(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class SessionChatMessageReceived extends SessionChatEvent {
  final SpaceMessage message;

  const SessionChatMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class SessionChatSendMessage extends SessionChatEvent {
  final String text;

  const SessionChatSendMessage(this.text);

  @override
  List<Object?> get props => [text];
}

class SessionChatStopped extends SessionChatEvent {
  const SessionChatStopped();
}
