import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../models/message_part.dart';
import '../../models/permission_request.dart';
import '../../models/space_message.dart';
import '../../models/tool_event.dart';
import '../../services/debug_logger.dart';
import '../../services/space_channel/session_activity_event.dart';
import '../../services/space_channel/space_channel_event.dart';
import '../../services/space_channel/space_channel_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SpaceChannelService _spaceChannel = GetIt.I<SpaceChannelService>();

  Map<String, SessionInfo> _sessions = {};
  final Map<String, Map<String, int>> _messageIndices = {};
  StreamSubscription<SpaceChannelEvent>? _eventSub;
  StreamSubscription<SessionActivityEvent>? _activitySub;
  StreamSubscription? _historySub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _toolHideTimer;
  ToolEvent? _activeToolEvent;
  bool _isThinking = false;

  static const int _maxMessagesPerSession = 100;
  static const String _defaultTargetSession = 'note-assistant';
  String _targetSession = _defaultTargetSession;

  ChatStatus _chatStatus = const ChatStatus();

  ChatBloc() : super(ChatInitial()) {
    on<SendChatMessage>(_onSendMessage);
    on<SendSessionMessage>(_onSendSessionMessage);
    on<CancelCurrentOperation>(_onCancelOperation);
    on<ClearMessages>(_onClearMessages);
    on<ClearChat>(_onClearChat);
    on<RetryMessage>(_onRetryMessage);
    on<DeleteQueuedMessage>(_onDeleteQueuedMessage);
    on<RespondToPermission>(_onRespondToPermission);
    on<SetTargetSession>(_onSetTargetSession);
    on<InternalMessageReceived>(_onMessageReceived);
    on<InternalHistoryReceived>(_onHistoryReceived);
    on<InternalSessionConnected>(_onSessionConnected);
    on<InternalSessionDisconnected>(_onSessionDisconnected);
    on<InternalToolEventReceived>(_onToolEventReceived);
    on<InternalStatusChanged>(_onStatusChanged);
    on<InternalConnectionChanged>(_onConnectionChanged);
    on<InternalRefreshState>((_, emit) => emit(_buildReady()));

    _subscribe();
  }

  void _subscribe() {
    _eventSub = _spaceChannel.eventStream.listen(_onSpaceChannelEvent);

    _historySub = _spaceChannel.historyBatches.listen((batch) {
      final messages = batch.events
          .where((e) =>
              e.from == 'assistant' ||
              e.sourceType == SpaceChannelSourceType.webhook)
          .map((e) => _convertEvent(e, batch.session))
          .toList();
      if (messages.isNotEmpty) {
        add(InternalHistoryReceived(batch.session, messages));
      }
    });

    _activitySub = _spaceChannel.sessionActivity.listen((activity) {
      switch (activity.type) {
        case SessionActivityType.connected:
          final e = activity.sessionEvent!;
          add(InternalSessionConnected(
            session: e.session,
            project: e.project ?? '',
            task: e.task ?? '',
          ));
        case SessionActivityType.disconnected:
          add(InternalSessionDisconnected(activity.session));
        case SessionActivityType.toolUse:
          add(InternalToolEventReceived(activity.toolEvent!));
        case SessionActivityType.status:
          final s = activity.statusEvent!;
          final activityState = switch (s.state) {
            'thinking' => SessionActivityState.thinking,
            _ => SessionActivityState.idle,
          };
          add(InternalStatusChanged(session: s.session, activityState: activityState));
      }
    });

    _connectionSub = _spaceChannel.connectionState.listen((connected) {
      add(InternalConnectionChanged(connected));
    });
  }

  SpaceMessage _convertEvent(SpaceChannelEvent e, String sessionId) {
    return SpaceMessage(
      id: e.id,
      sessionId: sessionId,
      role: 'assistant',
      created: e.ts != null
          ? DateTime.fromMillisecondsSinceEpoch(e.ts!)
          : DateTime.now(),
      parts: [MessagePart(id: '${e.id}-p0', type: 'text', content: e.text ?? '')],
      isStreaming: false,
      sourceType: e.sourceType == SpaceChannelSourceType.webhook ? 'webhook' : 'session',
      project: e.project,
      task: e.task,
      session: sessionId,
    );
  }

  SessionInfo _ensureSession(String session) {
    if (_sessions.containsKey(session)) return _sessions[session]!;
    final now = DateTime.now();
    final info = SessionInfo(
      session: session,
      project: '',
      task: '',
      connectedAt: now,
      lastActivity: now,
    );
    _sessions[session] = info;
    _messageIndices[session] = {};
    return info;
  }

  void _addMessage(String sessionId, SpaceMessage message) {
    final info = _ensureSession(sessionId);
    final indices = _messageIndices[sessionId]!;

    if (indices.containsKey(message.id)) return;

    final messages = List<SpaceMessage>.from(info.messages)..add(message);
    indices[message.id] = messages.length - 1;

    if (messages.length > _maxMessagesPerSession) {
      final toRemove = messages.length - _maxMessagesPerSession;
      for (var i = 0; i < toRemove; i++) {
        indices.remove(messages[i].id);
      }
      messages.removeRange(0, toRemove);
      indices.clear();
      for (var i = 0; i < messages.length; i++) {
        indices[messages[i].id] = i;
      }
    }

    _sessions[sessionId] = info.copyWith(
      messages: messages,
      lastActivity: DateTime.now(),
    );
  }

  void _onSpaceChannelEvent(SpaceChannelEvent event) {
    final sessionId = event.session ?? '';

    switch (event.type) {
      case SpaceChannelEventType.msg:
        if (event.from == 'assistant' ||
            event.sourceType == SpaceChannelSourceType.session ||
            event.sourceType == SpaceChannelSourceType.webhook) {
          final effectiveSession = sessionId.isNotEmpty ? sessionId : _targetSession;
          final message = _convertEvent(event, effectiveSession);
          add(InternalMessageReceived(effectiveSession, message));
        }

      case SpaceChannelEventType.permissionRequest:
        final permData = event.permissionData ?? {};
        final toolName = permData['tool_name'] ?? 'unknown';
        final description = permData['description'] ?? '';
        final effectiveSession = sessionId.isNotEmpty ? sessionId : _targetSession;
        final permMessage = SpaceMessage(
          id: event.id,
          sessionId: effectiveSession,
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
          session: effectiveSession,
        );
        add(InternalMessageReceived(effectiveSession, permMessage));

      case SpaceChannelEventType.edit:
        if (event.text != null && sessionId.isNotEmpty) {
          final indices = _messageIndices[sessionId];
          final idx = indices?[event.id];
          if (idx != null) {
            final info = _sessions[sessionId]!;
            final messages = List<SpaceMessage>.from(info.messages);
            final existing = messages[idx];
            messages[idx] = existing.copyWith(
              parts: [
                MessagePart(
                  id: existing.parts.isNotEmpty ? existing.parts.first.id : event.id,
                  type: 'text',
                  content: event.text,
                ),
              ],
            );
            _sessions[sessionId] = info.copyWith(messages: messages);
            add(InternalRefreshState());
          }
        }
    }
  }

  void _onMessageReceived(InternalMessageReceived event, Emitter<ChatState> emit) {
    _addMessage(event.sessionId, event.message);
    _chatStatus = _chatStatus.copyWith(isSending: false, clearErrorMessage: true);
    emit(_buildReady());
  }

  void _onHistoryReceived(InternalHistoryReceived event, Emitter<ChatState> emit) {
    final info = _ensureSession(event.sessionId);
    final existingIds = info.messages.map((m) => m.id).toSet();
    final newMessages = event.messages.where((m) => !existingIds.contains(m.id)).toList();
    if (newMessages.isEmpty) return;

    final merged = [...newMessages, ...info.messages];
    if (merged.length > _maxMessagesPerSession) {
      merged.removeRange(0, merged.length - _maxMessagesPerSession);
    }

    final indices = <String, int>{};
    for (var i = 0; i < merged.length; i++) {
      indices[merged[i].id] = i;
    }

    _sessions[event.sessionId] = info.copyWith(
      messages: merged,
      lastActivity: DateTime.now(),
    );
    _messageIndices[event.sessionId] = indices;
    emit(_buildReady());
  }

  void _onSessionConnected(InternalSessionConnected event, Emitter<ChatState> emit) {
    final now = DateTime.now();
    final existing = _sessions[event.session];
    _sessions[event.session] = SessionInfo(
      session: event.session,
      project: event.project,
      task: event.task,
      connectedAt: now,
      lastActivity: now,
      messages: existing == null ? [] : existing.messages,
      recentToolEvents: existing == null ? [] : existing.recentToolEvents,
    );
    _messageIndices.putIfAbsent(event.session, () => {});
    emit(_buildReady());
  }

  void _onSessionDisconnected(InternalSessionDisconnected event, Emitter<ChatState> emit) {
    _sessions.remove(event.session);
    _messageIndices.remove(event.session);
    emit(_buildReady());
  }

  void _onToolEventReceived(InternalToolEventReceived event, Emitter<ChatState> emit) {
    final toolEvent = event.toolEvent;
    final info = _ensureSession(toolEvent.session);

    final updatedEvents = [...info.recentToolEvents, toolEvent];
    final trimmed = updatedEvents.length > 10
        ? updatedEvents.sublist(updatedEvents.length - 10)
        : updatedEvents;

    _sessions[toolEvent.session] = info.copyWith(
      lastActivity: DateTime.now(),
      recentToolEvents: trimmed,
      activityState: SessionActivityState.toolUse,
    );

    if (toolEvent.session == _targetSession) {
      _toolHideTimer?.cancel();
      _activeToolEvent = toolEvent;
      _toolHideTimer = Timer(const Duration(seconds: 5), () {
        _activeToolEvent = null;
        add(InternalRefreshState());
      });
    }

    emit(_buildReady());
  }

  void _onStatusChanged(InternalStatusChanged event, Emitter<ChatState> emit) {
    final info = _ensureSession(event.session);
    _sessions[event.session] = info.copyWith(
      lastActivity: DateTime.now(),
      activityState: event.activityState,
    );

    if (event.session == _targetSession) {
      _isThinking = event.activityState == SessionActivityState.thinking;
    }

    emit(_buildReady());
  }

  void _onConnectionChanged(InternalConnectionChanged event, Emitter<ChatState> emit) {
    _chatStatus = _chatStatus.copyWith(isConnected: event.isConnected);
    if (!event.isConnected) {
      _chatStatus = _chatStatus.copyWith(isSending: false);
    }
    emit(_buildReady());
  }

  void _onSendMessage(SendChatMessage event, Emitter<ChatState> emit) {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = SpaceMessage(
      id: messageId,
      sessionId: _targetSession,
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

    _addMessage(_targetSession, userMessage);
    _chatStatus = _chatStatus.copyWith(isSending: true);
    emit(_buildReady());

    _spaceChannel.sendMessageToSession(_targetSession, event.message);
  }

  void _onSendSessionMessage(SendSessionMessage event, Emitter<ChatState> emit) {
    final msgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final userMessage = SpaceMessage(
      id: msgId,
      sessionId: event.sessionId,
      role: 'user',
      created: DateTime.now(),
      parts: [MessagePart(id: msgId, type: 'text', content: event.text)],
    );

    _addMessage(event.sessionId, userMessage);
    emit(_buildReady());

    _spaceChannel.sendMessageToSession(event.sessionId, event.text);
  }

  void _onCancelOperation(CancelCurrentOperation event, Emitter<ChatState> emit) {
    debugLogger.info('CC', 'Cancel operation requested');
    _chatStatus = _chatStatus.copyWith(isSending: false, clearErrorMessage: true);
    emit(_buildReady());
  }

  void _onClearMessages(ClearMessages event, Emitter<ChatState> emit) {
    _sessions = {};
    _messageIndices.clear();
    emit(_buildReady());
  }

  void _onClearChat(ClearChat event, Emitter<ChatState> emit) {
    _sessions = {};
    _messageIndices.clear();
    emit(ChatInitial());
  }

  void _onRetryMessage(RetryMessage event, Emitter<ChatState> emit) {
    _spaceChannel.sendMessageToSession(_targetSession, event.messageContent);
  }

  void _onDeleteQueuedMessage(DeleteQueuedMessage event, Emitter<ChatState> emit) {}

  void _onRespondToPermission(RespondToPermission event, Emitter<ChatState> emit) {
    for (final entry in _sessions.entries) {
      final messages = entry.value.messages;
      final idx = messages.indexWhere((m) => m.id == event.permissionId);
      if (idx == -1) continue;

      final msg = messages[idx];
      final updatedParts = msg.parts.map((p) {
        if (p.metadata?['pending_permission'] == true) {
          return MessagePart(
            id: p.id,
            type: p.type,
            content: p.content,
            metadata: {
              ...?p.metadata,
              'pending_permission': false,
              'permission_responded':
                  event.response == PermissionResponse.reject ? 'deny' : 'allow',
            },
          );
        }
        return p;
      }).toList();

      final updatedMessages = List<SpaceMessage>.from(messages);
      updatedMessages[idx] = msg.copyWith(parts: updatedParts);
      _sessions[entry.key] = entry.value.copyWith(messages: updatedMessages);

      _spaceChannel.sendPermissionResponse(
        msg.session ?? entry.key,
        event.permissionId,
        event.response == PermissionResponse.reject ? 'deny' : 'allow',
      );

      emit(_buildReady());
      return;
    }
  }

  void _onSetTargetSession(SetTargetSession event, Emitter<ChatState> emit) {
    _targetSession = event.sessionName;
    _activeToolEvent = null;
    _isThinking = false;
    _toolHideTimer?.cancel();

    final targetInfo = _sessions[_targetSession];
    if (targetInfo != null) {
      _isThinking = targetInfo.activityState == SessionActivityState.thinking;
    }

    emit(_buildReady());
  }

  ChatReady _buildReady() {
    return ChatReady(
      sessions: Map.unmodifiable(_sessions),
      targetSession: _targetSession,
      status: _chatStatus,
      activeToolEvent: _activeToolEvent,
      isThinking: _isThinking,
    );
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    _activitySub?.cancel();
    _historySub?.cancel();
    _connectionSub?.cancel();
    _toolHideTimer?.cancel();
    return super.close();
  }
}
