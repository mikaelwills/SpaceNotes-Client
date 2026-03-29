import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../models/message_part.dart';
import '../../models/permission_request.dart';
import '../../models/space_message.dart';
import '../../services/debug_logger.dart';
import '../../models/tool_event.dart';
import '../../services/space_channel/session_activity_event.dart';
import '../../services/space_channel/space_channel_event.dart';
import '../../services/space_channel/space_channel_service.dart';
import '../config/config_cubit.dart';
import '../config/config_state.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SpaceChannelService _spaceChannel = GetIt.I<SpaceChannelService>();

  final List<SpaceMessage> _messages = [];
  final Map<String, int> _messageIndex = {};
  StreamSubscription<SpaceChannelEvent>? _eventSub;
  StreamSubscription<SessionActivityEvent>? _activitySub;
  StreamSubscription? _configSub;
  Timer? _toolHideTimer;
  ToolEvent? _activeToolEvent;
  bool _isThinking = false;

  static const int _maxMessages = 100;
  static const String _sessionId = 'claude-code';
  static const String _defaultTargetSession = 'note-assistant';
  String _targetSession = _defaultTargetSession;
  String? _currentWsUrl;

  ChatStatus _chatStatus = const ChatStatus();

  ChatBloc() : super(ChatInitial()) {
    on<LoadMessagesForCurrentSession>(_onLoadMessages);
    on<SendChatMessage>(_onSendMessage);
    on<CancelCurrentOperation>(_onCancelOperation);
    on<ClearMessages>(_onClearMessages);
    on<ClearChat>(_onClearChat);
    on<RetryMessage>(_onRetryMessage);
    on<DeleteQueuedMessage>(_onDeleteQueuedMessage);
    on<RespondToPermission>(_onRespondToPermission);
    on<SessionErrorReceived>((e, emit) => emit(ChatError(e.error)));
    on<RefreshChatStateEvent>((e, emit) => emit(_createReadyState()));
    on<SetTargetSession>(_onSetTargetSession);

    _initialize();
    add(LoadMessagesForCurrentSession());
  }

  void _initialize() {
    final configCubit = GetIt.I<ConfigCubit>();

    _configSub = configCubit.stream.listen((state) {
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
    _subscribeToActivity();
  }

  void _connectToWebSocket(String wsUrl) {
    _currentWsUrl = wsUrl;
    debugLogger.info('CC', 'Connecting to WebSocket', wsUrl);

    _eventSub?.cancel();
    _spaceChannel.restartConnection();

    final stream = _spaceChannel.connect(wsUrl);
    _chatStatus = _chatStatus.copyWith(isConnected: true);

    _eventSub = stream.listen(
      _onSpaceChannelEvent,
      onError: (error) {
        debugLogger.error('CC', 'WebSocket error', error.toString());
        _chatStatus = _chatStatus.copyWith(
            isConnected: false, isSending: false, isStreaming: false);
        add(RefreshChatStateEvent());
      },
      onDone: () {
        debugLogger.info('CC', 'WebSocket closed');
        _chatStatus = _chatStatus.copyWith(
            isConnected: false, isSending: false, isStreaming: false);
        add(RefreshChatStateEvent());
      },
    );
  }

  void _subscribeToActivity() {
    _activitySub?.cancel();
    _activitySub = _spaceChannel.sessionActivity
        .where((a) => a.session == _targetSession)
        .listen((activity) {
      switch (activity.type) {
        case SessionActivityType.toolUse:
          _toolHideTimer?.cancel();
          _activeToolEvent = activity.toolEvent;
          add(RefreshChatStateEvent());
          _toolHideTimer = Timer(const Duration(seconds: 5), () {
            _activeToolEvent = null;
            add(RefreshChatStateEvent());
          });
        case SessionActivityType.status:
          _isThinking = activity.statusEvent?.state == 'thinking';
          add(RefreshChatStateEvent());
        case SessionActivityType.connected:
        case SessionActivityType.disconnected:
          break;
      }
    });
  }

  void _onSpaceChannelEvent(SpaceChannelEvent event) {
    switch (event.type) {
      case SpaceChannelEventType.msg:
        if (event.from == 'assistant' ||
            event.sourceType == SpaceChannelSourceType.session ||
            event.sourceType == SpaceChannelSourceType.webhook) {
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
          add(RefreshChatStateEvent());
        }

      case SpaceChannelEventType.permissionRequest:
        final permData = event.permissionData ?? {};
        final toolName = permData['tool_name'] ?? 'unknown';
        final description = permData['description'] ?? '';
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
        add(RefreshChatStateEvent());

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
            add(RefreshChatStateEvent());
          }
        }
    }
  }

  void _onLoadMessages(LoadMessagesForCurrentSession event, Emitter<ChatState> emit) {
    emit(_createReadyState());
  }

  void _onSendMessage(SendChatMessage event, Emitter<ChatState> emit) {
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

    _spaceChannel.sendMessageToSession(_targetSession, event.message);
  }

  void _onCancelOperation(CancelCurrentOperation event, Emitter<ChatState> emit) {
    debugLogger.info('CC', 'Cancel operation requested');
    _chatStatus = _chatStatus.copyWith(
        isSending: false, isStreaming: false, clearErrorMessage: true);
    emit(_createReadyState());
  }

  void _onClearMessages(ClearMessages event, Emitter<ChatState> emit) {
    _messages.clear();
    _messageIndex.clear();
    emit(_createReadyState());
  }

  void _onClearChat(ClearChat event, Emitter<ChatState> emit) {
    _messages.clear();
    _messageIndex.clear();
    emit(ChatInitial());
  }

  void _onRetryMessage(RetryMessage event, Emitter<ChatState> emit) {
    _spaceChannel.sendMessageToSession(_targetSession, event.messageContent);
  }

  void _onDeleteQueuedMessage(DeleteQueuedMessage event, Emitter<ChatState> emit) {}

  void _onRespondToPermission(RespondToPermission event, Emitter<ChatState> emit) {
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

    emit(_createReadyState());
  }

  void _onSetTargetSession(SetTargetSession event, Emitter<ChatState> emit) {
    _targetSession = event.sessionName;
    _activeToolEvent = null;
    _isThinking = false;
    _toolHideTimer?.cancel();
    _subscribeToActivity();
    emit(_createReadyState());
  }

  ChatReady _createReadyState() {
    return ChatReady(
      sessionId: _sessionId,
      messages: List.from(_messages),
      status: _chatStatus,
      targetSession: _targetSession,
      activeToolEvent: _activeToolEvent,
      isThinking: _isThinking,
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
  Future<void> close() {
    _configSub?.cancel();
    _eventSub?.cancel();
    _activitySub?.cancel();
    _toolHideTimer?.cancel();
    _spaceChannel.dispose();
    return super.close();
  }
}
