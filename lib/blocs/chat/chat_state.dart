import 'package:equatable/equatable.dart';
import '../../models/opencode_message.dart';
import '../../models/permission_request.dart';
import '../../models/session_status.dart';

enum ChatFlowPhase {
  idle,
  sending,
  awaitingResponse,
  streaming,
  failed,
  reconnecting,
}

class ChatTransitions {
  static const Map<ChatFlowPhase, Set<ChatFlowPhase>> validTransitions = {
    ChatFlowPhase.idle: {
      ChatFlowPhase.sending,
      ChatFlowPhase.reconnecting,
    },
    ChatFlowPhase.sending: {
      ChatFlowPhase.awaitingResponse,
      ChatFlowPhase.failed,
      ChatFlowPhase.reconnecting,
      ChatFlowPhase.streaming,
    },
    ChatFlowPhase.awaitingResponse: {
      ChatFlowPhase.streaming,
      ChatFlowPhase.failed,
      ChatFlowPhase.idle,
      ChatFlowPhase.reconnecting,
    },
    ChatFlowPhase.streaming: {
      ChatFlowPhase.idle,
      ChatFlowPhase.failed,
      ChatFlowPhase.reconnecting,
    },
    ChatFlowPhase.failed: {
      ChatFlowPhase.sending,
      ChatFlowPhase.idle,
      ChatFlowPhase.reconnecting,
    },
    ChatFlowPhase.reconnecting: {
      ChatFlowPhase.idle,
      ChatFlowPhase.failed,
    },
  };

  static bool canTransition(ChatFlowPhase from, ChatFlowPhase to) {
    return validTransitions[from]?.contains(to) ?? false;
  }
}

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
  final ChatFlowPhase phase;
  final bool isReconnectionRefresh;
  final SessionStatus? sessionStatus;
  final String? pendingMessageId;
  final String? errorMessage;

  const ChatReady({
    required this.sessionId,
    this.messages = const [],
    this.phase = ChatFlowPhase.idle,
    this.isReconnectionRefresh = false,
    this.sessionStatus,
    this.pendingMessageId,
    this.errorMessage,
  });

  bool get isIdle => phase == ChatFlowPhase.idle;
  bool get isSending => phase == ChatFlowPhase.sending;
  bool get isAwaitingResponse => phase == ChatFlowPhase.awaitingResponse;
  bool get isStreaming => phase == ChatFlowPhase.streaming;
  bool get isFailed => phase == ChatFlowPhase.failed;
  bool get isReconnecting => phase == ChatFlowPhase.reconnecting;

  bool get isWorking => isSending || isAwaitingResponse || isStreaming;
  bool get canSend => isIdle || isFailed;

  @override
  List<Object?> get props => [
        sessionId,
        messages,
        phase,
        isReconnectionRefresh,
        sessionStatus,
        pendingMessageId,
        errorMessage,
      ];

  ChatReady copyWith({
    String? sessionId,
    List<OpenCodeMessage>? messages,
    ChatFlowPhase? phase,
    bool? isReconnectionRefresh,
    SessionStatus? sessionStatus,
    String? pendingMessageId,
    String? errorMessage,
    bool clearPendingMessageId = false,
    bool clearErrorMessage = false,
  }) {
    return ChatReady(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      phase: phase ?? this.phase,
      isReconnectionRefresh: isReconnectionRefresh ?? this.isReconnectionRefresh,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      pendingMessageId: clearPendingMessageId ? null : (pendingMessageId ?? this.pendingMessageId),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
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
