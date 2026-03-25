import 'package:equatable/equatable.dart';
import 'message_part.dart';

/// Enum to track the sending status of a user-authored message.
enum MessageSendStatus {
  // Message has been successfully sent and acknowledged by the server.
  sent,
  // The message failed to send and can be retried.
  failed,
  // Message is queued for sending when network connection is restored.
  queued,
  // Message is currently being sent to the server.
  sending,
}

class SpaceMessage extends Equatable {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final DateTime created;
  final DateTime? completed;
  final List<MessagePart> parts;
  final bool isStreaming;
  final MessageSendStatus? sendStatus; // Nullable, only for user messages
  final String? sourceType;
  final String? project;
  final String? task;
  final String? session;

  const SpaceMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.created,
    this.completed,
    required this.parts,
    this.isStreaming = false,
    this.sendStatus,
    this.sourceType,
    this.project,
    this.task,
    this.session,
  });

  factory SpaceMessage.fromJson(Map<String, dynamic> json) {
    // Handle both direct message format and nested info format
    final info = json['info'] as Map<String, dynamic>?;
    final time = info?['time'] as Map<String, dynamic>?;
    
    // Extract ID from various possible locations
    final id = info?['id'] as String? ?? 
               json['id'] as String? ?? 
               DateTime.now().millisecondsSinceEpoch.toString();
    
    // Extract session ID
    final sessionId = info?['sessionID'] as String? ?? 
                      json['sessionID'] as String? ?? 
                      json['sessionId'] as String? ?? '';
    
    // Extract role
    final role = info?['role'] as String? ?? 
                 json['role'] as String? ?? 
                 'assistant';
    
    // Handle timestamps (could be milliseconds or ISO strings)
    DateTime createdTime;
    try {
      final createdValue = time?['created'] ?? json['created'];
      if (createdValue is int) {
        createdTime = DateTime.fromMillisecondsSinceEpoch(createdValue);
      } else if (createdValue is String) {
        createdTime = DateTime.parse(createdValue);
      } else {
        createdTime = DateTime.now();
      }
    } catch (e) {
      createdTime = DateTime.now();
    }
    
    DateTime? completedTime;
    try {
      final completedValue = time?['completed'] ?? json['completed'];
      if (completedValue is int) {
        completedTime = DateTime.fromMillisecondsSinceEpoch(completedValue);
      } else if (completedValue is String) {
        completedTime = DateTime.parse(completedValue);
      }
    } catch (e) {
      completedTime = null;
    }

    return SpaceMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      created: createdTime,
      completed: completedTime,
      parts: (json['parts'] as List<dynamic>?)
              ?.map((part) => MessagePart.fromJson(part as Map<String, dynamic>))
              .toList() ??
          [],
      isStreaming: json['isStreaming'] as bool? ?? 
                   (completedTime == null && role == 'assistant'),
    );
  }



  /// Factory constructor specifically for Space API responses
  factory SpaceMessage.fromApiResponse(Map<String, dynamic> json) {
    // Handle both direct message format and nested info format
    final info = json['info'] as Map<String, dynamic>?;
    final timeData = info?['time'] as Map<String, dynamic>? ?? json['time'] as Map<String, dynamic>?;

    // Extract ID from various possible locations
    final messageId = info?['id'] as String? ??
                      json['id'] as String? ??
                      DateTime.now().millisecondsSinceEpoch.toString();

    // Extract session ID
    final sessionId = info?['sessionID'] as String? ??
                      json['sessionID'] as String? ??
                      json['sessionId'] as String? ??
                      json['session_id'] as String? ?? '';

    // Extract role
    final role = info?['role'] as String? ??
                 json['role'] as String? ??
                 'assistant';

    // Handle timestamps
    DateTime createdTime = DateTime.now();
    DateTime? completedTime;

    if (timeData != null) {
      try {
        if (timeData['created'] != null) {
          createdTime = DateTime.fromMillisecondsSinceEpoch(timeData['created'] as int);
        }
        if (timeData['completed'] != null) {
          completedTime = DateTime.fromMillisecondsSinceEpoch(timeData['completed'] as int);
        }
      } catch (e) {
        print('❌ [SpaceMessage] Error parsing time: $e');
      }
    }
    
    // Parse parts - this is the key part that was missing
    final partsList = json['parts'] as List<dynamic>? ?? [];
    final parts = partsList.map((partData) {
      return MessagePart.fromJson(partData as Map<String, dynamic>);
    }).toList();
    
    
    // A message is only streaming if:
    // 1. It's an assistant message AND
    // 2. It has no completed time AND  
    // 3. At least one part doesn't have an end time
    bool isMessageStreaming = false;
    if (role == 'assistant' && completedTime == null) {
      // Check if any text parts are still streaming (no end time)
      for (final part in parts) {
        if (part.type == 'text' && part.metadata != null) {
          final timeData = part.metadata!['time'] as Map<String, dynamic>?;
          if (timeData != null && timeData['end'] == null) {
            isMessageStreaming = true;
            break;
          }
        }
      }
    }
    
    final message = SpaceMessage(
      id: messageId,
      sessionId: sessionId,
      role: role,
      created: createdTime,
      completed: completedTime,
      parts: parts,
      isStreaming: isMessageStreaming,
    );
    
    return message;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'created': created.toIso8601String(),
      'completed': completed?.toIso8601String(),
      'parts': parts.map((part) => part.toJson()).toList(),
      'isStreaming': isStreaming,
      'sendStatus': sendStatus?.toString(),
      if (sourceType != null) 'sourceType': sourceType,
      if (project != null) 'project': project,
      if (task != null) 'task': task,
      if (session != null) 'session': session,
    };
  }

  SpaceMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    DateTime? created,
    DateTime? completed,
    List<MessagePart>? parts,
    bool? isStreaming,
    MessageSendStatus? sendStatus,
    String? sourceType,
    String? project,
    String? task,
    String? session,
  }) {
    return SpaceMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      created: created ?? this.created,
      completed: completed ?? this.completed,
      parts: parts ?? this.parts,
      isStreaming: isStreaming ?? this.isStreaming,
      sendStatus: sendStatus ?? this.sendStatus,
      sourceType: sourceType ?? this.sourceType,
      project: project ?? this.project,
      task: task ?? this.task,
      session: session ?? this.session,
    );
  }

  /// Get the combined text content from all text parts
  String get content {
    return parts
        .where((part) => part.type == 'text' && part.content != null)
        .map((part) => part.content!)
        .join('\n')
        .trim();
  }

  @override
  List<Object?> get props => [id, sessionId, role, created, completed, parts, isStreaming, sendStatus, sourceType, project, task, session];
}