import 'package:equatable/equatable.dart';
import '../../models/permission_request.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class LoadMessagesForCurrentSession extends ChatEvent {}

class SendChatMessage extends ChatEvent {
  final String message;
  final String? imageBase64;
  final String? imageMimeType;

  const SendChatMessage(this.message, {this.imageBase64, this.imageMimeType});

  @override
  List<Object> get props => [message, imageBase64 ?? '', imageMimeType ?? ''];
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

class RefreshChatStateEvent extends ChatEvent {}

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

class SessionErrorReceived extends ChatEvent {
  final String error;

  const SessionErrorReceived(this.error);

  @override
  List<Object> get props => [error];
}

class SetTargetSession extends ChatEvent {
  final String sessionName;

  const SetTargetSession(this.sessionName);

  @override
  List<Object> get props => [sessionName];
}
