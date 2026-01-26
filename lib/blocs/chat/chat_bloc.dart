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
  final Map<String, int> _messageIndex = {};
  StreamSubscription? _eventSubscription;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _permanentSessionSubscription;

  static const int _maxMessages = 100;
  static const Duration _debounceInterval = Duration(milliseconds: 50);

  ChatStatus _chatStatus = const ChatStatus();
  Timer? _debounceTimer;
  bool _hasPendingEmit = false;

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
      _chatStatus = const ChatStatus();

      final messages = await openCodeClient.getSessionMessages(currentSessionId);
      debugLogger.chat('LoadMessages: Fetched ${messages.length} messages');

      for (final message in messages) {
        _messages.add(message);
        _messageIndex[message.id] = _messages.length - 1;
      }

      _startListening(currentSessionId);

      debugLogger.chat('LoadMessages: Ready', 'messageCount=${_messages.length}');
      emit(_createChatReadyState());

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
        _updateStatus(isConnected: false);
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

    if (!_chatStatus.canSend) {
      debugLogger.chatError('Send: Cannot send', 'status=$_chatStatus');
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

    _updateStatus(isSending: true, pendingMessageId: messageId);

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
      _updateStatus(isSending: false, errorMessage: e.toString());
      emit(_createChatReadyState());
    }
  }

  String? _addUserMessage(String sessionId, String content) {
    if (sessionId == sessionBloc.currentSessionId) {
      final existingUserMessages = _messages.where((msg) =>
          msg.role == 'user' &&
          msg.parts.isNotEmpty &&
          msg.parts.first.content == content &&
          msg.sendStatus != MessageSendStatus.failed);

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
        sendStatus: MessageSendStatus.sent,
      );

      _messages.add(userMessage);
      _messageIndex[userMessage.id] = _messages.length - 1;
      _enforceMessageLimit();

      return messageId;
    }
    return null;
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
              _updateStatus(isStreaming: true);
              _debouncedEmit(emit);
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
            _updateStatus(isStreaming: true, isSending: false);
            _debouncedEmit(emit);
          }
        }
        break;

      case 'session.idle':
        debugLogger.chat('SSE: session.idle', 'streaming complete');
        _handleSessionIdle();
        _emitCurrentState(emit);
        break;

      case 'permission.asked':
        if (sseEvent.data != null) {
          try {
            final permission = PermissionRequest.fromJson(sseEvent.data!);
            debugLogger.chat('SSE: permission.asked', 'permission=${permission.permission}');
            emit(ChatPermissionRequired(
              sessionId: sessionBloc.currentSessionId!,
              permission: permission,
              messages: List.from(_messages),
            ));
          } catch (e) {
            debugLogger.chatError('SSE: permission.asked parse error', e.toString());
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
      case 'session.diff':
        break;

      default:
        debugLogger.chatDebug('SSE: Ignoring event', sseEvent.type);
    }
  }

  void _debouncedEmit(Emitter<ChatState> emit) {
    _hasPendingEmit = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceInterval, () {
      if (_hasPendingEmit) {
        _hasPendingEmit = false;
        if (sessionBloc.currentSessionId != null) {
          emit(_createChatReadyState());
        }
      }
    });
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
    _messages.clear();
    _messageIndex.clear();
    _eventSubscription?.cancel();
    _eventSubscription = null;
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
    _messages.removeAt(queuedMessageIndex);
    _rebuildMessageIndex();

    emit(_createChatReadyState());
  }

  void _onMessageStatusChanged(
    MessageStatusChanged event,
    Emitter<ChatState> emit,
  ) {
    final status = event.status;

    if (status == MessageSendStatus.sent) {
      _updateStatus(isSending: false);
      emit(_createChatReadyState());
    } else if (status == MessageSendStatus.failed) {
      _updateStatus(isSending: false, errorMessage: 'Message failed to send');
      emit(_createChatReadyState());
    } else if (status == MessageSendStatus.queued) {
      _updateStatus(isSending: false);
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

      final messageId =
          sseEvent.messageId ?? partData['messageID'] ?? partData['messageId'];
      final partId = partData['id'] as String?;
      final partType = partData['type'] as String?;
      final partText = partData['text'] as String?;
      final delta = partData['delta'] as String?;

      if (messageId != null) {
        final messageIndex = _messageIndex[messageId];

        if (messageIndex != null && messageIndex < _messages.length) {
          final currentMessage = _messages[messageIndex];
          final updatedParts = List<MessagePart>.from(currentMessage.parts);
          final partIndex = updatedParts.indexWhere((p) => p.id == partId);

          if (partIndex != -1) {
            final existingPart = updatedParts[partIndex];
            if (partType == 'tool' || existingPart.type == 'tool') {
              debugLogger.chatDebug('SSE: tool update by ID', 'partId=$partId status=${partData['status']} error=${partData['error']}');
            } else {
              debugLogger.chatDebug('SSE: part update', 'updating part by ID: $partId type=$partType');
            }

            String? newContent;
            if (delta != null && partType == 'text') {
              final currentContent = existingPart.content ?? '';
              newContent = currentContent + delta;
            } else {
              newContent = partText ?? existingPart.content;
            }

            final mergedMetadata = <String, dynamic>{
              ...?existingPart.metadata,
              ...partData,
            };

            updatedParts[partIndex] = MessagePart(
              id: partId ?? existingPart.id,
              type: partType ?? existingPart.type,
              content: newContent,
              metadata: mergedMetadata,
            );
          } else {
            if (partType == 'tool') {
              final toolName = partData['tool'] as String?;
              final toolStatus = partData['status'] ?? partData['state'];
              debugLogger.chatDebug('SSE: tool event', 'tool=$toolName status=$toolStatus');

              final existingToolIndex = toolName != null
                ? updatedParts.indexWhere((p) =>
                    p.type == 'tool' && p.metadata?['tool'] == toolName)
                : updatedParts.indexWhere((p) => p.type == 'tool');

              if (existingToolIndex != -1) {
                debugLogger.chatDebug('SSE: tool update', 'updating existing tool by name at index $existingToolIndex');
                final existingTool = updatedParts[existingToolIndex];
                final mergedToolMetadata = <String, dynamic>{
                  ...?existingTool.metadata,
                  ...partData,
                };
                updatedParts[existingToolIndex] = MessagePart(
                  id: existingTool.id,
                  type: 'tool',
                  content: partText ?? existingTool.content,
                  metadata: mergedToolMetadata,
                );
              } else {
                debugLogger.chatDebug('SSE: tool add', 'adding new tool: $toolName');
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
                metadata: partData,
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
      debugLogger.chatError('SSE: part update error', e.toString());
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

    _updateStatus(isStreaming: false, isSending: false, clearError: true);
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
      _updateStatus(isStreaming: false, isSending: false);
    }
  }

  bool _isDuplicateContent(String content, String role) {
    if (content.trim().isEmpty) return false;

    final now = DateTime.now();
    final contentLower = content.toLowerCase().trim();

    final sameRoleRecentMessages = _messages.where((msg) =>
        msg.role == role && now.difference(msg.created).inSeconds < 30);

    for (final message in sameRoleRecentMessages) {
      if (message.parts.isNotEmpty) {
        final messageContent = message.parts
            .where((part) => part.type == 'text')
            .map((part) => part.content ?? '')
            .join(' ')
            .trim();

        if (messageContent.toLowerCase() == contentLower) {
          debugLogger.chatDebug('Duplicate: same-role detected', 'role=$role');
          return true;
        }
      }
    }

    if (role == 'assistant') {
      final recentUserMessages = _messages.where((msg) =>
          msg.role == 'user' && now.difference(msg.created).inSeconds < 10);

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

          if (contentLower.length > userContent.length * 1.5) {
            continue;
          }

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

      for (int i = 0; i < messagesToRemove; i++) {
        final removedMessage = _messages.removeAt(0);
        _messageIndex.remove(removedMessage.id);
      }

      _messageIndex.clear();
      for (int i = 0; i < _messages.length; i++) {
        _messageIndex[_messages[i].id] = i;
      }

      debugLogger.chatDebug('Limit: Removed $messagesToRemove old messages');
    }
  }

  void _updateStatus({
    bool? isSending,
    bool? isStreaming,
    bool? isConnected,
    String? pendingMessageId,
    String? errorMessage,
    bool clearError = false,
  }) {
    _chatStatus = _chatStatus.copyWith(
      isSending: isSending,
      isStreaming: isStreaming,
      isConnected: isConnected,
      pendingMessageId: pendingMessageId,
      errorMessage: errorMessage,
      clearErrorMessage: clearError,
    );
  }

  ChatReady _createChatReadyState() {
    return ChatReady(
      sessionId: sessionBloc.currentSessionId!,
      messages: List.from(_messages),
      status: _chatStatus,
    );
  }

  void _rebuildMessageIndex() {
    _messageIndex.clear();
    for (int i = 0; i < _messages.length; i++) {
      _messageIndex[_messages[i].id] = i;
    }
  }

  void _emitCurrentState(Emitter<ChatState> emit) {
    _debounceTimer?.cancel();
    _hasPendingEmit = false;
    if (sessionBloc.currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  void _updateMessageStatus(String messageId, MessageSendStatus status) {
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
        _updateStatus(isConnected: false);
      },
    );

    _updateStatus(isConnected: true);
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
    _debounceTimer?.cancel();
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    _permanentSessionSubscription?.cancel();
    messageQueueService.dispose();
    return super.close();
  }
}
