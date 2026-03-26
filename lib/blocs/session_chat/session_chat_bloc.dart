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

  static const int _maxMessages = 100;

  SessionChatBloc(this._spaceChannel, {required String sessionId})
      : super(SessionChatState(sessionId: sessionId)) {
    on<SessionChatStarted>(_onStarted);
    on<SessionChatMessageReceived>(_onMessageReceived);
    on<SessionChatSendMessage>(_onSendMessage);
    on<SessionChatStopped>(_onStopped);
  }

  void _onStarted(SessionChatStarted event, Emitter<SessionChatState> emit) {
    _eventSub?.cancel();
    _eventSub = _spaceChannel.eventsForSession(event.sessionId).listen((e) {
      if (e.type == SpaceChannelEventType.msg && e.from == 'assistant') {
        final message = SpaceMessage(
          id: e.id,
          sessionId: state.sessionId,
          role: 'assistant',
          created: DateTime.now(),
          parts: [MessagePart(id: e.id, type: 'text', content: e.text ?? '')],
          sourceType: 'session',
          project: e.project,
          task: e.task,
          session: e.session,
        );
        add(SessionChatMessageReceived(message));
      }
    });
    emit(state.copyWith(isConnected: true));
  }

  void _onMessageReceived(SessionChatMessageReceived event, Emitter<SessionChatState> emit) {
    final updated = [...state.messages, event.message];
    final trimmed = updated.length > _maxMessages
        ? updated.sublist(updated.length - _maxMessages)
        : updated;
    emit(state.copyWith(messages: trimmed));
  }

  void _onSendMessage(SessionChatSendMessage event, Emitter<SessionChatState> emit) {
    _spaceChannel.sendMessageToSession(state.sessionId, event.text);
    final msgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final message = SpaceMessage(
      id: msgId,
      sessionId: state.sessionId,
      role: 'user',
      created: DateTime.now(),
      parts: [MessagePart(id: msgId, type: 'text', content: event.text)],
    );
    final updated = [...state.messages, message];
    final trimmed = updated.length > _maxMessages
        ? updated.sublist(updated.length - _maxMessages)
        : updated;
    emit(state.copyWith(messages: trimmed));
  }

  void _onStopped(SessionChatStopped event, Emitter<SessionChatState> emit) {
    _eventSub?.cancel();
    _eventSub = null;
    emit(state.copyWith(isConnected: false));
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}
