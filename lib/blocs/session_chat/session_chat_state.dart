import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';

class SessionChatState extends Equatable {
  final Map<String, List<SpaceMessage>> messagesBySession;

  const SessionChatState({
    this.messagesBySession = const {},
  });

  List<SpaceMessage> messagesFor(String sessionId) {
    return messagesBySession[sessionId] ?? const [];
  }

  SessionChatState copyWith({
    Map<String, List<SpaceMessage>>? messagesBySession,
  }) {
    return SessionChatState(
      messagesBySession: messagesBySession ?? this.messagesBySession,
    );
  }

  @override
  List<Object?> get props => [messagesBySession];
}
