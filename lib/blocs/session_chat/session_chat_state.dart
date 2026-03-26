import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';

class SessionChatState extends Equatable {
  final String sessionId;
  final List<SpaceMessage> messages;
  final bool isConnected;

  const SessionChatState({
    required this.sessionId,
    this.messages = const [],
    this.isConnected = false,
  });

  SessionChatState copyWith({
    List<SpaceMessage>? messages,
    bool? isConnected,
  }) {
    return SessionChatState(
      sessionId: sessionId,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [sessionId, messages, isConnected];
}
