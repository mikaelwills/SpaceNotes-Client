import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/message_part.dart';
import '../../models/space_message.dart';
import '../../services/space_channel_service.dart';
import 'session_chat_event.dart';
import 'session_chat_state.dart';

class SessionChatBloc extends Bloc<SessionChatEvent, SessionChatState> {
  final SpaceChannelService _spaceChannel;
  StreamSubscription<SpaceChannelEvent>? _eventSub;

  static const int _maxMessagesPerSession = 100;

  SessionChatBloc(this._spaceChannel) : super(const SessionChatState()) {
    on<SessionChatMessageReceived>(_onMessageReceived);
    on<SessionChatSendMessage>(_onSendMessage);
    on<SessionChatSessionRemoved>(_onSessionRemoved);

    _eventSub = _spaceChannel.eventStream.listen((e) {
      if (e.session == null || e.session!.isEmpty) return;

      final isAssistantMsg = e.type == SpaceChannelEventType.msg && e.from == 'assistant';
      final isWebhook = e.sourceType == SpaceChannelSourceType.webhook;

      if (isAssistantMsg || isWebhook) {
        final role = isWebhook ? 'webhook' : 'assistant';
        final message = SpaceMessage(
          id: e.id,
          sessionId: e.session!,
          role: role,
          created: DateTime.now(),
          parts: [MessagePart(id: e.id, type: 'text', content: e.text ?? '')],
          sourceType: isWebhook ? 'webhook' : 'session',
          project: e.project,
          task: e.task,
          session: e.session,
        );
        add(SessionChatMessageReceived(e.session!, message));
      }
    });
  }

  void _onMessageReceived(
      SessionChatMessageReceived event, Emitter<SessionChatState> emit) {
    final messages = List<SpaceMessage>.from(
        state.messagesBySession[event.sessionId] ?? []);
    messages.add(event.message);
    if (messages.length > _maxMessagesPerSession) {
      messages.removeRange(0, messages.length - _maxMessagesPerSession);
    }
    emit(state.copyWith(
      messagesBySession: {
        ...state.messagesBySession,
        event.sessionId: messages,
      },
    ));
  }

  void _onSendMessage(
      SessionChatSendMessage event, Emitter<SessionChatState> emit) {
    _spaceChannel.sendMessageToSession(event.sessionId, event.text);
    final msgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final message = SpaceMessage(
      id: msgId,
      sessionId: event.sessionId,
      role: 'user',
      created: DateTime.now(),
      parts: [MessagePart(id: msgId, type: 'text', content: event.text)],
    );
    final messages = List<SpaceMessage>.from(
        state.messagesBySession[event.sessionId] ?? []);
    messages.add(message);
    if (messages.length > _maxMessagesPerSession) {
      messages.removeRange(0, messages.length - _maxMessagesPerSession);
    }
    emit(state.copyWith(
      messagesBySession: {
        ...state.messagesBySession,
        event.sessionId: messages,
      },
    ));
  }

  void _onSessionRemoved(
      SessionChatSessionRemoved event, Emitter<SessionChatState> emit) {
    final updated =
        Map<String, List<SpaceMessage>>.from(state.messagesBySession)
          ..remove(event.sessionId);
    emit(state.copyWith(messagesBySession: updated));
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}
