import 'package:equatable/equatable.dart';
import '../../models/permission_request.dart';
import '../../models/space_message.dart';
import '../../models/tool_event.dart';
import 'chat_state.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class SendChatMessage extends ChatEvent {
  final String message;
  final String? imageBase64;
  final String? imageMimeType;

  const SendChatMessage(this.message, {this.imageBase64, this.imageMimeType});

  @override
  List<Object> get props => [message, imageBase64 ?? '', imageMimeType ?? ''];
}

class SendSessionMessage extends ChatEvent {
  final String sessionId;
  final String text;

  const SendSessionMessage(this.sessionId, this.text);

  @override
  List<Object> get props => [sessionId, text];
}

class CancelCurrentOperation extends ChatEvent {}

class ClearMessages extends ChatEvent {}

class ClearChat extends ChatEvent {}

class RetryMessage extends ChatEvent {
  final String messageContent;

  const RetryMessage(this.messageContent);

  @override
  List<Object> get props => [messageContent];
}

class DeleteQueuedMessage extends ChatEvent {
  final String messageContent;

  const DeleteQueuedMessage(this.messageContent);

  @override
  List<Object> get props => [messageContent];
}

class RespondToPermission extends ChatEvent {
  final String permissionId;
  final PermissionResponse response;

  const RespondToPermission({
    required this.permissionId,
    required this.response,
  });

  @override
  List<Object> get props => [permissionId, response];
}

class SetTargetSession extends ChatEvent {
  final String sessionName;

  const SetTargetSession(this.sessionName);

  @override
  List<Object> get props => [sessionName];
}

class InternalMessageReceived extends ChatEvent {
  final String sessionId;
  final SpaceMessage message;

  const InternalMessageReceived(this.sessionId, this.message);

  @override
  List<Object> get props => [sessionId, message];
}

class InternalHistoryReceived extends ChatEvent {
  final String sessionId;
  final List<SpaceMessage> messages;

  const InternalHistoryReceived(this.sessionId, this.messages);

  @override
  List<Object> get props => [sessionId, messages];
}

class InternalSessionConnected extends ChatEvent {
  final String session;
  final String project;
  final String task;

  const InternalSessionConnected({
    required this.session,
    required this.project,
    required this.task,
  });

  @override
  List<Object> get props => [session, project, task];
}

class InternalSessionDisconnected extends ChatEvent {
  final String session;

  const InternalSessionDisconnected(this.session);

  @override
  List<Object> get props => [session];
}

class InternalToolEventReceived extends ChatEvent {
  final ToolEvent toolEvent;

  const InternalToolEventReceived(this.toolEvent);

  @override
  List<Object> get props => [toolEvent];
}

class InternalStatusChanged extends ChatEvent {
  final String session;
  final SessionActivityState activityState;

  const InternalStatusChanged({required this.session, required this.activityState});

  @override
  List<Object> get props => [session, activityState];
}

class InternalConnectionChanged extends ChatEvent {
  final bool isConnected;

  const InternalConnectionChanged(this.isConnected);

  @override
  List<Object> get props => [isConnected];
}

class InternalRefreshState extends ChatEvent {}

class ClearTransientActivity extends ChatEvent {
  const ClearTransientActivity();
}
