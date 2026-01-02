import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/debug_logger.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;
import '../session/session_state.dart';
import '../../services/sse_service.dart';
import '../../services/opencode_client.dart';
import '../../services/message_queue_service.dart';
import '../../models/opencode_message.dart';
import '../../models/opencode_event.dart';
import '../../models/message_part.dart';
import '../../models/permission_request.dart';
import '../../models/session_status.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SessionBloc sessionBloc;
  final SSEService sseService;
  final OpenCodeClient openCodeClient;
  final MessageQueueService messageQueueService;

  final List<OpenCodeMessage> _messages = [];
  final Map<String, int> _messageIndex = {}; // messageId -> index mapping
  StreamSubscription? _eventSubscription;
  StreamSubscription? _sessionSubscription; // For temporary subscriptions (e.g., in _onSendChatMessage)
  StreamSubscription? _permanentSessionSubscription; // For constructor subscription

  static const int _maxMessages = 100;

  ChatBloc({
    required this.sessionBloc,
    required this.sseService,
    required this.openCodeClient,
    required this.messageQueueService,
  }) : super(ChatInitial()) {
    on<LoadMessagesForCurrentSession>(_onLoadMessagesForCurrentSession);
    on<SendChatMessage>(_onSendChatMessage);
    on<CancelCurrentOperation>(_onCancelCurrentOperation);
    on<SSEEventReceived>(_onSSEEventReceived);
    on<ClearMessages>(_onClearMessages);
    on<ClearChat>(_onClearChat);
    on<AddUserMessage>(_onAddUserMessage);
    on<RetryMessage>(_onRetryMessage);
    on<DeleteQueuedMessage>(_onDeleteQueuedMessage);
    on<MessageStatusChanged>(_onMessageStatusChanged);
    on<RespondToPermission>(_onRespondToPermission);
    on<SessionErrorReceived>(_onSessionErrorReceived);

    _permanentSessionSubscription = sessionBloc.stream.listen((sessionState) {
      if (sessionState is SessionLoaded) {
        add(LoadMessagesForCurrentSession());
      } else if (sessionState is SessionError) {
        debugLogger.chatError('Session error received', sessionState.message);
        add(SessionErrorReceived(sessionState.message));
      }
    });

    if (sessionBloc.state is SessionLoaded) {
      add(LoadMessagesForCurrentSession());
    }
  }

  Future<void> _onLoadMessagesForCurrentSession(
    LoadMessagesForCurrentSession event,
    Emitter<ChatState> emit,
  ) async {
    final currentSessionId = sessionBloc.currentSessionId;

    if (currentSessionId == null) {
      debugLogger.chatError('LoadMessages: No session ID');
      return;
    }

    try {
      debugLogger.chat('LoadMessages: Starting', 'sessionId=$currentSessionId');
      emit(ChatConnecting());

      _messages.clear();
      _messageIndex.clear();
      _currentPhase = ChatFlowPhase.idle;
      _pendingMessageId = null;
      _errorMessage = null;

      final messages = await openCodeClient.getSessionMessages(currentSessionId);
      debugLogger.chat('LoadMessages: Fetched ${messages.length} messages');

      for (final message in messages) {
        _messages.add(message);
        _messageIndex[message.id] = _messages.length - 1;
      }

      _startListening(currentSessionId);

      debugLogger.chat('LoadMessages: Ready', 'messageCount=${_messages.length}');
      emit(ChatReady(sessionId: currentSessionId, messages: List.from(_messages)));

    } catch (e) {
      debugLogger.chatError('LoadMessages: Failed', e.toString());
      emit(const ChatError('Failed to load messages. Please try again.'));
    }
  }

  void _startListening(String sessionId) {
    _eventSubscription?.cancel();
    debugLogger.chat('SSE: Starting listener', 'sessionId=$sessionId');

    _eventSubscription = sseService.connectToEventStream().listen(
      (sseEvent) {
        if (sseEvent.sessionId == sessionBloc.currentSessionId) {
          add(SSEEventReceived(sseEvent));
        }
      },
      onError: (error) {
        debugLogger.chatError('SSE: Stream error', error.toString());
      },
    );
  }

  Future<void> _onSendChatMessage(
    SendChatMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatReady) {
      debugLogger.chatError('Send: Not in ChatReady state', 'state=${currentState.runtimeType}');
      return;
    }

    if (!currentState.canSend) {
      debugLogger.chatError('Send: Cannot send in current phase', 'phase=${currentState.phase}');
      return;
    }

    final sessionId = currentState.sessionId;
    final msgPreview = event.message.length > 50 ? '${event.message.substring(0, 50)}...' : event.message;
    debugLogger.chat('Send: Starting', 'session=$sessionId, msg="$msgPreview"');

    final messageId = _addUserMessage(sessionId, event.message);

    if (messageId == null) {
      debugLogger.chatError('Send: Failed to create message');
      return;
    }

    if (!_tryTransition(ChatFlowPhase.sending)) {
      debugLogger.chatError('Send: Failed to transition to sending');
      return;
    }

    _pendingMessageId = messageId;

    try {
      debugLogger.chat('Send: Created message', 'msgId=$messageId');
      emit(_createChatReadyState());

      messageQueueService.sendMessage(
        messageId: messageId,
        sessionId: sessionId,
        content: event.message,
        imageBase64: event.imageBase64,
        imageMimeType: event.imageMimeType,
        onStatusChange: (status) {
          debugLogger.chat('Send: Status change', 'msgId=$messageId, status=$status');
          _updateMessageStatus(messageId, status);
          add(MessageStatusChanged(status));
        },
      );

    } catch (e) {
      debugLogger.chatError('Send: Exception', 'msgId=$messageId, error=$e');
      _updateMessageStatus(messageId, MessageSendStatus.failed);
      _tryTransition(ChatFlowPhase.failed);
      _errorMessage = e.toString();
      emit(_createChatReadyState());
    }
  }

  String? _addUserMessage(String sessionId, String content) {
    if (sessionId == sessionBloc.currentSessionId) {
      // Check if we already have a user message with the same content to prevent duplicates
      final existingUserMessages = _messages.where((msg) =>
          msg.role == 'user' &&
          msg.parts.isNotEmpty &&
          msg.parts.first.content == content &&
          msg.sendStatus != MessageSendStatus.failed); // Don't skip failed messages that are being retried

      if (existingUserMessages.isNotEmpty) {
        return existingUserMessages.first.id;
      }

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final userMessage = OpenCodeMessage(
        id: messageId,
        sessionId: sessionId,
        role: 'user',
        created: DateTime.now(),
        parts: [
          MessagePart(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'text',
            content: content,
          ),
        ],
        sendStatus: MessageSendStatus.sent, // Default to sent
      );

      _messages.add(userMessage);
      _messageIndex[userMessage.id] = _messages.length - 1;
      _enforceMessageLimit();

      return messageId;
    }
    return null; // Session mismatch
  }

  Future<void> _onCancelCurrentOperation(
    CancelCurrentOperation event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatReady) {
      final sessionId = currentState.sessionId;

      try {
        sessionBloc.add(session_events.CancelSessionOperation(sessionId));
        _handleSessionAborted(sessionId);
        emit(_createChatReadyState());
      } catch (e) {
        emit(ChatError('Failed to cancel operation: ${e.toString()}'));
      }
    }
  }

  void _onSSEEventReceived(
    SSEEventReceived event,
    Emitter<ChatState> emit,
  ) {
    final sseEvent = event.event;

    if (sseEvent.sessionId != sessionBloc.currentSessionId) {
      return;
    }

    debugLogger.sseDebug('Event: ${sseEvent.type}', 'msgId=${sseEvent.messageId}');

    switch (sseEvent.type) {
      case 'message.updated':
        if (sseEvent.data != null) {
          try {
            final properties = sseEvent.data!['properties'] as Map<String, dynamic>?;
            if (properties != null) {
              final message = OpenCodeMessage.fromJson(properties);

              if (message.role == 'user') {
                return;
              }

              debugLogger.chat('SSE: message.updated', 'msgId=${message.id}, role=${message.role}');
              _updateOrAddMessage(message);
              _emitCurrentState(emit);
            }
          } catch (e) {
            debugLogger.chatError('SSE: message.updated parse error', e.toString());
          }
        }
        break;
      case 'message.part.updated':
        if (sseEvent.data != null) {
          final stateChanged = _handlePartialUpdate(sseEvent);
          if (stateChanged) {
            _emitCurrentState(emit);
          }
        }
        break;
      case 'session.idle':
        debugLogger.chat('SSE: session.idle', 'streaming complete');
        _handleSessionIdle();
        _emitCurrentState(emit);
        break;
      case 'permission.updated':
        if (sseEvent.data != null) {
          try {
            final permission = PermissionRequest.fromJson(sseEvent.data!);
            debugLogger.chat('SSE: permission.updated', 'type=${permission.type}');
            emit(ChatPermissionRequired(
              sessionId: sessionBloc.currentSessionId!,
              permission: permission,
              messages: List.from(_messages),
            ));
          } catch (e) {
            debugLogger.chatError('SSE: permission.updated parse error', e.toString());
          }
        }
        break;
      case 'session.status':
        if (sseEvent.data != null) {
          try {
            final status = SessionStatus.fromJson(sseEvent.data!);
            debugLogger.chatDebug('SSE: session.status', 'status=$status');
            final currentState = state;
            if (currentState is ChatReady) {
              emit(currentState.copyWith(sessionStatus: status));
            }
          } catch (e) {
            debugLogger.chatError('SSE: session.status parse error', e.toString());
          }
        }
        break;
      case 'storage.write':
      case 'session.updated':
        break;
      default:
        debugLogger.chatDebug('SSE: Unknown event type', sseEvent.type);
    }
  }

  void _onClearMessages(
    ClearMessages event,
    Emitter<ChatState> emit,
  ) {
    _messages.clear();
    _messageIndex.clear();
    if (sessionBloc.currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  void _onClearChat(
    ClearChat event,
    Emitter<ChatState> emit,
  ) {
    // Clear all chat state and prepare for new session
    _messages.clear();
    _messageIndex.clear();
    
    // Cancel any existing event subscription
    _eventSubscription?.cancel();
    _eventSubscription = null;
    
    // Emit initial state
    emit(ChatInitial());
  }

  void _onAddUserMessage(
    AddUserMessage event,
    Emitter<ChatState> emit,
  ) {
    final currentSessionId = sessionBloc.currentSessionId;
    if (currentSessionId != null) {
      _addUserMessage(currentSessionId, event.content);
      _emitCurrentState(emit);
    }
  }

  Future<void> _onRetryMessage(
    RetryMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatReady) {
      return;
    }

    final sessionId = currentState.sessionId;

    final failedMessageIndex = _messages.lastIndexWhere((msg) =>
        msg.role == 'user' &&
        msg.parts.isNotEmpty &&
        msg.parts.first.content == event.messageContent &&
        msg.sendStatus == MessageSendStatus.failed);

    if (failedMessageIndex == -1) {
      return;
    }

    final failedMessage = _messages[failedMessageIndex];
    final messageId = failedMessage.id;

    // Retry message via MessageQueueService using existing message ID (non-blocking)
    messageQueueService.retryMessage(
      messageId: messageId,
      sessionId: sessionId,
      content: event.messageContent,
      onStatusChange: (status) {
        _updateMessageStatus(messageId, status);
        add(MessageStatusChanged(status));
      },
    );
  }

  void _onDeleteQueuedMessage(
    DeleteQueuedMessage event,
    Emitter<ChatState> emit,
  ) {
    final queuedMessageIndex = _messages.lastIndexWhere((msg) =>
        msg.role == 'user' &&
        msg.parts.isNotEmpty &&
        msg.parts.first.content == event.messageContent &&
        msg.sendStatus == MessageSendStatus.queued);

    if (queuedMessageIndex == -1) {
      return;
    }

    final queuedMessage = _messages[queuedMessageIndex];
    final messageId = queuedMessage.id;

    messageQueueService.removeFromQueue(messageId);
    
    // Remove the message from local display
    _messages.removeAt(queuedMessageIndex);
    
    // Update message index
    _rebuildMessageIndex();
    
    emit(_createChatReadyState());
  }

  void _onMessageStatusChanged(
    MessageStatusChanged event,
    Emitter<ChatState> emit,
  ) {
    final status = event.status;

    if (status == MessageSendStatus.sent) {
      _tryTransition(ChatFlowPhase.awaitingResponse);
      emit(_createChatReadyState());
    } else if (status == MessageSendStatus.failed) {
      _tryTransition(ChatFlowPhase.failed);
      _errorMessage = 'Message failed to send';
      emit(_createChatReadyState());
    } else if (status == MessageSendStatus.queued) {
      _tryTransition(ChatFlowPhase.idle);
      emit(_createChatReadyState());
    }
  }

  void _updateOrAddMessage(OpenCodeMessage message) {
    final messageIndex = _messageIndex[message.id];

    if (messageIndex != null && messageIndex < _messages.length) {
      final existingMessage = _messages[messageIndex];

      if (message.parts.isEmpty && existingMessage.parts.isNotEmpty) {
        return;
      }

      _messages[messageIndex] = message;
    } else {
      final messageContent = message.parts
          .where((part) => part.type == 'text')
          .map((part) => part.content ?? '')
          .join(' ')
          .trim();

      if (_isDuplicateContent(messageContent, message.role)) {
        return;
      }

      _messages.add(message);
      _messageIndex[message.id] = _messages.length - 1;
      _enforceMessageLimit();
    }
  }

  bool _handlePartialUpdate(OpenCodeEvent sseEvent) {
    try {
      Map<String, dynamic>? partData;
      if (sseEvent.data != null &&
          sseEvent.data!['properties'] is Map<String, dynamic>) {
        final properties = sseEvent.data!['properties'] as Map<String, dynamic>;
        if (properties['part'] is Map<String, dynamic>) {
          partData = properties['part'] as Map<String, dynamic>;
        }
      }

      if (partData == null) {
        return false;
      }

      if (_currentPhase == ChatFlowPhase.awaitingResponse ||
          _currentPhase == ChatFlowPhase.sending) {
        _tryTransition(ChatFlowPhase.streaming);
      }

      final messageId =
          sseEvent.messageId ?? partData['messageID'] ?? partData['messageId'];
      final partId = partData['id'] as String?;
      final partType = partData['type'] as String?;
      final partText = partData['text'] as String?;
      final delta = partData['delta'] as String?; // Extract delta for streaming

      if (messageId != null) {
        final messageIndex = _messageIndex[messageId];

        if (messageIndex != null && messageIndex < _messages.length) {
          final currentMessage = _messages[messageIndex];

          // Update or add the part to the message
          final updatedParts = List<MessagePart>.from(currentMessage.parts);
          final partIndex = updatedParts.indexWhere((p) => p.id == partId);

          if (partIndex != -1) {
            // Update existing part
            final existingPart = updatedParts[partIndex];

            String? newContent;
            if (delta != null && partType == 'text') {
              final currentContent = existingPart.content ?? '';
              newContent = currentContent + delta;
            } else {
              newContent = partText ?? existingPart.content;
            }

            updatedParts[partIndex] = MessagePart(
              id: partId ?? existingPart.id,
              type: partType ?? existingPart.type,
              content: newContent,
              metadata: partData,
            );
          } else {
            if (partType == 'tool') {
              final toolName = partData['tool'] as String?;

              final existingToolIndex = toolName != null
                ? updatedParts.indexWhere((p) =>
                    p.type == 'tool' && p.metadata?['tool'] == toolName)
                : updatedParts.indexWhere((p) => p.type == 'tool');

              if (existingToolIndex != -1) {
                updatedParts[existingToolIndex] = MessagePart(
                  id: updatedParts[existingToolIndex].id,
                  type: 'tool',
                  content: partText ?? updatedParts[existingToolIndex].content,
                  metadata: partData.isNotEmpty ? partData : updatedParts[existingToolIndex].metadata,
                );
                return true;
              } else {
                updatedParts.add(MessagePart(
                  id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  type: 'tool',
                  content: partText,
                  metadata: partData,
                ));
              }
            } else {
              updatedParts.add(MessagePart(
                id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                type: partType ?? 'text',
                content: partText,
                metadata: partData,
              ));
            }
          }

          final updatedMessage = currentMessage.copyWith(
            parts: updatedParts,
            isStreaming: true,
          );

          _messages[messageIndex] = updatedMessage;
        } else {
          if (partText != null) {
            final isUserEcho = _messages.any((msg) =>
                msg.role == 'user' &&
                msg.parts.isNotEmpty &&
                msg.parts.any((p) => p.type == 'text' && p.content == partText));

            if (isUserEcho) {
              return true;
            }
          }

          final newMessage = OpenCodeMessage(
            id: messageId,
            sessionId: sseEvent.sessionId ?? sessionBloc.currentSessionId ?? '',
            role: 'assistant',
            created: DateTime.now(),
            parts: [
              MessagePart(
                id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                type: partType ?? 'text',
                content: partText,
                metadata: partData['time'] as Map<String, dynamic>?,
              ),
            ],
            isStreaming: true,
          );

          _messages.add(newMessage);
          _messageIndex[newMessage.id] = _messages.length - 1;
          _enforceMessageLimit();
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleSessionIdle() {
    if (_messages.isNotEmpty) {
      final lastMessage = _messages.last;
      if (lastMessage.role == 'assistant' && lastMessage.isStreaming) {
        final completedMessage = lastMessage.copyWith(
          isStreaming: false,
          completed: DateTime.now(),
        );
        _messages[_messages.length - 1] = completedMessage;
      }
    }

    _tryTransition(ChatFlowPhase.idle);
  }

  void _handleSessionAborted(String sessionId) {
    if (sessionId == sessionBloc.currentSessionId) {
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        if (lastMessage.role == 'assistant' && lastMessage.isStreaming) {
          final completedMessage = lastMessage.copyWith(
            isStreaming: false,
            completed: DateTime.now(),
          );
          _messages[_messages.length - 1] = completedMessage;
        }
      }
      _tryTransition(ChatFlowPhase.idle);
    }
  }

  /// Smart duplicate detection that blocks exact echoes but allows legitimate responses
  bool _isDuplicateContent(String content, String role) {
    if (content.trim().isEmpty) return false;

    final now = DateTime.now();
    final contentLower = content.toLowerCase().trim();

    // 1. Check for same-role duplicates (actual duplicate messages)
    final sameRoleRecentMessages = _messages.where((msg) =>
        msg.role == role && now.difference(msg.created).inSeconds < 30);

    for (final message in sameRoleRecentMessages) {
      if (message.parts.isNotEmpty) {
        final messageContent = message.parts
            .where((part) => part.type == 'text')
            .map((part) => part.content ?? '')
            .join(' ')
            .trim();

        // Check for exact content match (case insensitive)
        if (messageContent.toLowerCase() == contentLower) {
          debugLogger.chatDebug('Duplicate: same-role detected', 'role=$role');
          return true;
        }
      }
    }

    // 2. Check for exact echoes from opposite role (server echoing user input)
    if (role == 'assistant') {
      final recentUserMessages = _messages.where((msg) =>
          msg.role == 'user' && now.difference(msg.created).inSeconds < 10); // Shorter window for echoes

      for (final message in recentUserMessages) {
        if (message.parts.isNotEmpty) {
          final userContent = message.parts
              .where((part) => part.type == 'text')
              .map((part) => part.content ?? '')
              .join(' ')
              .trim()
              .toLowerCase();

          if (userContent == contentLower) {
            debugLogger.chatDebug('Duplicate: exact echo blocked');
            return true;
          }

          // If assistant message is much longer, it's probably a legitimate response that includes the user's content
          if (contentLower.length > userContent.length * 1.5) {
            continue;
          }

          // Check if it starts with common response patterns (legitimate responses)
          final responsePatterns = [
            'i\'ll help you',
            'i can help',
            'let me help',
            'to test',
            'for testing',
            'you can test',
            'here\'s how',
            'to do this',
          ];

          bool isLegitimateResponse = responsePatterns.any((pattern) => 
              contentLower.startsWith(pattern));

          if (isLegitimateResponse) {
            continue;
          }

          // If it contains the user content but has additional meaningful content, allow it
          if (contentLower.contains(userContent) && contentLower.length > userContent.length + 10) {
            continue;
          }
        }
      }
    }

    return false;
  }

  void _enforceMessageLimit() {
    if (_messages.length > _maxMessages) {
      final messagesToRemove = _messages.length - _maxMessages;

      // Remove old messages and update index map
      for (int i = 0; i < messagesToRemove; i++) {
        final removedMessage = _messages.removeAt(0);
        _messageIndex.remove(removedMessage.id);
      }

      // Update remaining message indices
      _messageIndex.clear();
      for (int i = 0; i < _messages.length; i++) {
        _messageIndex[_messages[i].id] = i;
      }

      debugLogger.chatDebug('Limit: Removed $messagesToRemove old messages');
    }
  }

  ChatFlowPhase _currentPhase = ChatFlowPhase.idle;
  String? _pendingMessageId;
  String? _errorMessage;

  bool _tryTransition(ChatFlowPhase newPhase) {
    if (_currentPhase == newPhase) {
      return true;
    }

    if (ChatTransitions.canTransition(_currentPhase, newPhase)) {
      debugLogger.chat('Phase transition', '$_currentPhase → $newPhase');
      _currentPhase = newPhase;
      if (newPhase == ChatFlowPhase.idle) {
        _pendingMessageId = null;
        _errorMessage = null;
      }
      return true;
    }

    debugLogger.chatError('Invalid transition', '$_currentPhase → $newPhase');
    return false;
  }

  ChatReady _createChatReadyState() {
    return ChatReady(
      sessionId: sessionBloc.currentSessionId!,
      messages: List.from(_messages),
      phase: _currentPhase,
      pendingMessageId: _pendingMessageId,
      errorMessage: _errorMessage,
    );
  }

  void _rebuildMessageIndex() {
    _messageIndex.clear();
    for (int i = 0; i < _messages.length; i++) {
      _messageIndex[_messages[i].id] = i;
    }
  }

  void _emitCurrentState(Emitter<ChatState> emit) {
    if (sessionBloc.currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  void _updateMessageStatus(String messageId, MessageSendStatus status) {
    // Use O(1) lookup with message index map
    final index = _messageIndex[messageId];
    
    if (index != null && index < _messages.length) {
      final originalMessage = _messages[index];
      _messages[index] = originalMessage.copyWith(sendStatus: status);
      debugLogger.chatDebug('Status update', 'msgId=$messageId, status=$status');
    } else {
      debugLogger.chatError('Status update: Message not found', 'msgId=$messageId');
    }
  }

  void restartSSESubscription() {
    debugLogger.chat('SSE: Restarting subscription');
    _eventSubscription?.cancel();

    _eventSubscription = sseService.connectToEventStream().listen(
      (sseEvent) {
        if (sseEvent.sessionId == sessionBloc.currentSessionId) {
          add(SSEEventReceived(sseEvent));
        }
      },
      onError: (error) {
        debugLogger.chatError('SSE: Stream error after restart', error.toString());
      },
    );

    debugLogger.chat('SSE: Subscription restarted');
  }

  Future<void> _onRespondToPermission(
    RespondToPermission event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final sessionId = sessionBloc.currentSessionId;
      if (sessionId == null) {
        debugLogger.chatError('Permission: No session ID');
        return;
      }

      debugLogger.chat('Permission: Responding', 'response=${event.response.value}');
      await openCodeClient.respondToPermission(
        sessionId,
        event.permissionId,
        event.response,
      );

      debugLogger.chat('Permission: Response sent');
      emit(_createChatReadyState());
    } catch (e) {
      debugLogger.chatError('Permission: Failed to respond', e.toString());
      emit(const ChatError('Failed to respond to permission request'));
    }
  }

  void _onSessionErrorReceived(
    SessionErrorReceived event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatError(event.error));
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    _permanentSessionSubscription?.cancel();
    messageQueueService.dispose();
    return super.close();
  }
}
