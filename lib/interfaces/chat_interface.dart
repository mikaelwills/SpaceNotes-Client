import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../models/space_message.dart';

abstract class ChatInterface {
  List<SpaceMessage> get messages;
  ChatStatus get chatStatus;

  void setAddEvent(void Function(ChatEvent) addEvent);
  Future<void> initialize();

  Future<void> onLoadMessages(Emitter<ChatState> emit);
  Future<void> onSendMessage(SendChatMessage event, Emitter<ChatState> emit);
  Future<void> onCancelOperation(Emitter<ChatState> emit);
  void onClearMessages(Emitter<ChatState> emit);
  void onClearChat(Emitter<ChatState> emit);
  Future<void> onRetryMessage(RetryMessage event, Emitter<ChatState> emit);
  void onDeleteQueuedMessage(DeleteQueuedMessage event, Emitter<ChatState> emit);
  void onMessageStatusChanged(MessageStatusChanged event, Emitter<ChatState> emit);
  Future<void> onRespondToPermission(RespondToPermission event, Emitter<ChatState> emit);
  void onRefreshState(Emitter<ChatState> emit);
  void onSetTargetSession(SetTargetSession event, Emitter<ChatState> emit);

  void dispose();
}
