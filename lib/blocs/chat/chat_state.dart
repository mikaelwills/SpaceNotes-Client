import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';
import '../../models/permission_request.dart';
import '../../models/session_status.dart';

class ChatStatus extends Equatable {
  final bool isSending;
  final bool isStreaming;
  final bool isConnected;
  final String? pendingMessageId;
  final String? errorMessage;

  const ChatStatus({
    this.isSending = false,
    this.isStreaming = false,
    this.isConnected = true,
    this.pendingMessageId,
    this.errorMessage,
  });

  bool get isIdle => !isSending && !isStreaming;
  bool get isFailed => errorMessage != null;
  bool get isWorking => isSending || isStreaming;
  bool get canSend => isIdle && isConnected;

  ChatStatus copyWith({
    bool? isSending,
    bool? isStreaming,
    bool? isConnected,
    String? pendingMessageId,
    String? errorMessage,
    bool clearPendingMessageId = false,
    bool clearErrorMessage = false,
  }) {
    return ChatStatus(
      isSending: isSending ?? this.isSending,
      isStreaming: isStreaming ?? this.isStreaming,
      isConnected: isConnected ?? this.isConnected,
      pendingMessageId:
          clearPendingMessageId ? null : (pendingMessageId ?? this.pendingMessageId),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSending, isStreaming, isConnected, pendingMessageId, errorMessage];
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
  final List<SpaceMessage> messages;
  final ChatStatus status;
  final bool isReconnectionRefresh;
  final SessionStatus? sessionStatus;
  final String targetSession;

  const ChatReady({
    required this.sessionId,
    this.messages = const [],
    this.status = const ChatStatus(),
    this.isReconnectionRefresh = false,
    this.sessionStatus,
    this.targetSession = 'note-assistant',
  });

  bool get isIdle => status.isIdle;
  bool get isSending => status.isSending;
  bool get isStreaming => status.isStreaming;
  bool get isFailed => status.isFailed;
  bool get isConnected => status.isConnected;
  bool get isWorking => status.isWorking;
  bool get canSend => status.canSend;
  String? get pendingMessageId => status.pendingMessageId;
  String? get errorMessage => status.errorMessage;

  @override
  List<Object?> get props => [
        sessionId,
        messages,
        status,
        isReconnectionRefresh,
        sessionStatus,
        targetSession,
      ];

  ChatReady copyWith({
    String? sessionId,
    List<SpaceMessage>? messages,
    ChatStatus? status,
    bool? isReconnectionRefresh,
    SessionStatus? sessionStatus,
    String? targetSession,
  }) {
    return ChatReady(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      isReconnectionRefresh: isReconnectionRefresh ?? this.isReconnectionRefresh,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      targetSession: targetSession ?? this.targetSession,
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
  final List<SpaceMessage> messages;

  const ChatPermissionRequired({
    required this.sessionId,
    required this.permission,
    this.messages = const [],
  });

  @override
  List<Object> get props => [sessionId, permission, messages];
}
