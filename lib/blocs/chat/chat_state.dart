import 'package:equatable/equatable.dart';
import '../../models/space_message.dart';
import '../../models/tool_event.dart';

enum SessionActivityState { idle, thinking, toolUse }

class SessionInfo extends Equatable {
  final String session;
  final String task;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final List<SpaceMessage> messages;
  final List<ToolEvent> recentToolEvents;
  final SessionActivityState activityState;

  const SessionInfo({
    required this.session,
    required this.task,
    required this.connectedAt,
    required this.lastActivity,
    this.messages = const [],
    this.recentToolEvents = const [],
    this.activityState = SessionActivityState.idle,
  });

  SessionInfo copyWith({
    DateTime? lastActivity,
    List<SpaceMessage>? messages,
    List<ToolEvent>? recentToolEvents,
    SessionActivityState? activityState,
  }) {
    return SessionInfo(
      session: session,
      task: task,
      connectedAt: connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      messages: messages ?? this.messages,
      recentToolEvents: recentToolEvents ?? this.recentToolEvents,
      activityState: activityState ?? this.activityState,
    );
  }

  @override
  List<Object?> get props => [
        session,
        task,
        connectedAt,
        lastActivity,
        messages,
        recentToolEvents,
        activityState,
      ];
}

class ChatStatus extends Equatable {
  final bool isSending;
  final bool isConnected;
  final String? errorMessage;

  const ChatStatus({
    this.isSending = false,
    this.isConnected = false,
    this.errorMessage,
  });

  bool get isIdle => !isSending;
  bool get isFailed => errorMessage != null;
  bool get canSend => isIdle && isConnected;

  ChatStatus copyWith({
    bool? isSending,
    bool? isConnected,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatStatus(
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSending, isConnected, errorMessage];
}

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatReady extends ChatState {
  final Map<String, SessionInfo> sessions;
  final String targetSession;
  final ChatStatus status;
  final ToolEvent? activeToolEvent;
  final bool isThinking;

  const ChatReady({
    this.sessions = const {},
    this.targetSession = 'note-assistant',
    this.status = const ChatStatus(),
    this.activeToolEvent,
    this.isThinking = false,
  });

  bool get isConnected => status.isConnected;
  bool get isSending => status.isSending;
  bool get isWorking => status.isSending;
  bool get isIdle => status.isIdle;
  bool get canSend => status.canSend;
  String? get errorMessage => status.errorMessage;

  List<SpaceMessage> get allMessages {
    final all = <SpaceMessage>[];
    for (final session in sessions.values) {
      all.addAll(session.messages);
    }
    all.sort((a, b) => a.created.compareTo(b.created));
    return all;
  }

  List<SpaceMessage> messagesFor(String sessionId) {
    final session = sessions[sessionId];
    return session == null ? const [] : session.messages;
  }

  @override
  List<Object?> get props => [
        sessions,
        targetSession,
        status,
        activeToolEvent,
        isThinking,
      ];
}

class ChatError extends ChatState {
  final String error;

  const ChatError(this.error);

  @override
  List<Object> get props => [error];
}
