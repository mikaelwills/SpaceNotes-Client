import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../services/debug_logger.dart';
import '../services/space_channel_service.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../models/space_message.dart';
import '../models/message_part.dart';
import '../models/permission_request.dart';
import 'chat_interface.dart';

class ClaudeCodeChatInterface implements ChatInterface {
  final SpaceChannelService _spaceChannel = GetIt.I<SpaceChannelService>();

  final List<SpaceMessage> _messages = [];
  final Map<String, int> _messageIndex = {};
  StreamSubscription? _wsSubscription;
  StreamSubscription? _configSubscription;

  static const int _maxMessages = 100;
  static const String _sessionId = 'claude-code';

  ChatStatus _chatStatus = const ChatStatus();
  void Function(ChatEvent)? _addEvent;

  @override
  List<SpaceMessage> get messages => _messages;

  @override
  ChatStatus get chatStatus => _chatStatus;

  @override
  void setAddEvent(void Function(ChatEvent) addEvent) {
    _addEvent = addEvent;
  }

  String? _currentWsUrl;

  @override
  Future<void> initialize() async {
    final configCubit = GetIt.I<ConfigCubit>();

    _configSubscription?.cancel();
    _configSubscription = configCubit.stream.listen((state) {
      if (state is ConfigLoaded) {
        final newUrl = state.claudeCodeWsUrl;
        if (newUrl != _currentWsUrl) {
          debugLogger.info('CC', 'Config changed, reconnecting', newUrl);
          _connectToWebSocket(newUrl);
        }
      }
    });

    final configState = configCubit.state;
    final wsUrl = configState is ConfigLoaded
        ? configState.claudeCodeWsUrl
        : 'ws://0.0.0.0:${ConfigLoaded.claudeCodePort}/ws';

    _connectToWebSocket(wsUrl);
  }

  void _connectToWebSocket(String wsUrl) {
    _currentWsUrl = wsUrl;
    debugLogger.info('CC', 'Connecting to WebSocket', wsUrl);

    _wsSubscription?.cancel();
    _spaceChannel.restartConnection();

    final stream = _spaceChannel.connect(wsUrl);
    _chatStatus = _chatStatus.copyWith(isConnected: true);

    _wsSubscription = stream.listen(
      (event) {
        switch (event.type) {
          case SpaceChannelEventType.msg:
            if (event.from == 'assistant' || event.sourceType == SpaceChannelSourceType.worker || event.sourceType == SpaceChannelSourceType.webhook) {
              final message = SpaceMessage(
                id: event.id,
                sessionId: _sessionId,
                role: 'assistant',
                created: event.ts != null
                    ? DateTime.fromMillisecondsSinceEpoch(event.ts!)
                    : DateTime.now(),
                completed: DateTime.now(),
                parts: [
                  MessagePart(
                    id: '${event.id}-p0',
                    type: 'text',
                    content: event.text ?? '',
                  ),
                ],
                isStreaming: false,
                sourceType: event.sourceType?.name,
                project: event.project,
                task: event.task,
                session: event.session,
              );

              _messages.add(message);
              _messageIndex[message.id] = _messages.length - 1;
              _enforceMessageLimit();
              _chatStatus = _chatStatus.copyWith(
                  isSending: false, isStreaming: false, clearErrorMessage: true);
              _addEvent?.call(RefreshChatStateEvent());
            }
            break;

          case SpaceChannelEventType.permissionRequest:
            final permData = event.permissionData ?? {};
            final toolName = permData['tool_name'] as String? ?? 'unknown';
            final description = permData['description'] as String? ?? '';
            final permMessage = SpaceMessage(
              id: event.id,
              sessionId: _sessionId,
              role: 'assistant',
              created: DateTime.now(),
              completed: DateTime.now(),
              parts: [
                MessagePart(
                  id: '${event.id}-p0',
                  type: 'text',
                  content: '$toolName: $description',
                  metadata: {
                    'request_id': permData['request_id'],
                    'tool_name': toolName,
                    'input_preview': permData['input_preview'] ?? '',
                    'pending_permission': true,
                  },
                ),
              ],
              isStreaming: false,
              sourceType: event.sourceType?.name,
              project: event.project,
              task: event.task,
              session: event.session,
            );

            _messages.add(permMessage);
            _messageIndex[permMessage.id] = _messages.length - 1;
            _enforceMessageLimit();
            _addEvent?.call(RefreshChatStateEvent());
            break;

          case SpaceChannelEventType.edit:
            if (event.text != null) {
              final idx = _messageIndex[event.id];
              if (idx != null && idx < _messages.length) {
                final existing = _messages[idx];
                _messages[idx] = existing.copyWith(
                  parts: [
                    MessagePart(
                      id: existing.parts.isNotEmpty ? existing.parts.first.id : event.id,
                      type: 'text',
                      content: event.text,
                    ),
                  ],
                );
                _addEvent?.call(RefreshChatStateEvent());
              }
            }
            break;
        }
      },
      onError: (error) {
        debugLogger.error('CC', 'WebSocket error', error.toString());
        _chatStatus = _chatStatus.copyWith(
            isConnected: false, isSending: false, isStreaming: false);
        _addEvent?.call(RefreshChatStateEvent());
      },
      onDone: () {
        debugLogger.info('CC', 'WebSocket closed');
        _chatStatus = _chatStatus.copyWith(
            isConnected: false, isSending: false, isStreaming: false);
        _addEvent?.call(RefreshChatStateEvent());
      },
    );
  }

  @override
  Future<void> onLoadMessages(Emitter<ChatState> emit) async {
    emit(_createReadyState());
  }

  @override
  Future<void> onSendMessage(SendChatMessage event, Emitter<ChatState> emit) async {

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = SpaceMessage(
      id: messageId,
      sessionId: _sessionId,
      role: 'user',
      created: DateTime.now(),
      completed: DateTime.now(),
      parts: [
        MessagePart(
          id: '$messageId-p0',
          type: 'text',
          content: event.message,
        ),
      ],
      sendStatus: MessageSendStatus.sent,
    );

    _messages.add(userMessage);
    _messageIndex[userMessage.id] = _messages.length - 1;
    _enforceMessageLimit();

    _chatStatus = _chatStatus.copyWith(isSending: true);
    emit(_createReadyState());

    _spaceChannel.sendMessage(event.message);
  }

  @override
  Future<void> onCancelOperation(Emitter<ChatState> emit) async {
    debugLogger.info('CC', 'Cancel operation requested');
    _chatStatus = _chatStatus.copyWith(
        isSending: false, isStreaming: false, clearErrorMessage: true);
    emit(_createReadyState());
  }

  @override
  void onClearMessages(Emitter<ChatState> emit) {
    _messages.clear();
    _messageIndex.clear();
    emit(_createReadyState());
  }

  @override
  void onClearChat(Emitter<ChatState> emit) {
    _messages.clear();
    _messageIndex.clear();
    emit(ChatInitial());
  }

  @override
  Future<void> onRetryMessage(RetryMessage event, Emitter<ChatState> emit) async {
    _spaceChannel.sendMessage(event.messageContent);
  }

  @override
  void onDeleteQueuedMessage(DeleteQueuedMessage event, Emitter<ChatState> emit) {}

  @override
  void onMessageStatusChanged(MessageStatusChanged event, Emitter<ChatState> emit) {}

  @override
  Future<void> onRespondToPermission(RespondToPermission event, Emitter<ChatState> emit) async {
    final idx = _messages.indexWhere((m) => m.id == event.permissionId);
    if (idx == -1) return;

    final msg = _messages[idx];
    final updatedParts = msg.parts.map((p) {
      if (p.metadata?['pending_permission'] == true) {
        return MessagePart(
          id: p.id,
          type: p.type,
          content: p.content,
          metadata: {
            ...?p.metadata,
            'pending_permission': false,
            'permission_responded': event.response == PermissionResponse.reject ? 'deny' : 'allow',
          },
        );
      }
      return p;
    }).toList();

    _messages[idx] = msg.copyWith(parts: updatedParts);

    _spaceChannel.sendPermissionResponse(
      msg.session ?? '',
      event.permissionId,
      event.response == PermissionResponse.reject ? 'deny' : 'allow',
    );

    _addEvent?.call(RefreshChatStateEvent());
  }

  @override
  void onRefreshState(Emitter<ChatState> emit) {
    emit(_createReadyState());
  }

  ChatReady _createReadyState() {
    return ChatReady(
      sessionId: _sessionId,
      messages: List.from(_messages),
      status: _chatStatus,
    );
  }

  void _enforceMessageLimit() {
    if (_messages.length > _maxMessages) {
      final toRemove = _messages.length - _maxMessages;
      for (int i = 0; i < toRemove; i++) {
        final removed = _messages.removeAt(0);
        _messageIndex.remove(removed.id);
      }
      _messageIndex.clear();
      for (int i = 0; i < _messages.length; i++) {
        _messageIndex[_messages[i].id] = i;
      }
    }
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _wsSubscription?.cancel();
    _spaceChannel.dispose();
  }
}
