import 'package:equatable/equatable.dart';
import '../../models/opencode_message.dart';
import '../../models/permission_request.dart';
import '../../models/session_status.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatConnecting extends ChatState {}

class ChatReady extends ChatState {
  final String sessionId;
  final List<OpenCodeMessage> messages;
  final bool isStreaming;
  final bool isReconnectionRefresh;
  final SessionStatus? sessionStatus;

  const ChatReady({
    required this.sessionId,
    this.messages = const [],
    this.isStreaming = false,
    this.isReconnectionRefresh = false,
    this.sessionStatus,
  });

  @override
  List<Object?> get props => [sessionId, messages, isStreaming, isReconnectionRefresh, sessionStatus];

  ChatReady copyWith({
    String? sessionId,
    List<OpenCodeMessage>? messages,
    bool? isStreaming,
    bool? isReconnectionRefresh,
    SessionStatus? sessionStatus,
  }) {
    return ChatReady(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isReconnectionRefresh: isReconnectionRefresh ?? this.isReconnectionRefresh,
      sessionStatus: sessionStatus ?? this.sessionStatus,
    );
  }
}

class ChatSendingMessage extends ChatState {
  final String sessionId;
  final String message;
  final List<OpenCodeMessage> messages;

  const ChatSendingMessage({
    required this.sessionId,
    required this.message,
    this.messages = const [],
  });

  @override
  List<Object> get props => [sessionId, message, messages];
}

class ChatError extends ChatState {
  final String error;

  const ChatError(this.error);

  @override
  List<Object> get props => [error];
}

class ChatPermissionRequired extends ChatState {
  final String sessionId;
  final PermissionRequest permission;
  final List<OpenCodeMessage> messages;

  const ChatPermissionRequired({
    required this.sessionId,
    required this.permission,
    this.messages = const [],
  });

  @override
  List<Object> get props => [sessionId, permission, messages];
}
