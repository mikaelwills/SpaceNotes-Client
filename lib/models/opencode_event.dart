import 'package:equatable/equatable.dart';

class OpenCodeEvent extends Equatable {
  final String type;
  final String? sessionId;
  final String? messageId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const OpenCodeEvent({
    required this.type,
    this.sessionId,
    this.messageId,
    this.data,
    required this.timestamp,
  });

  factory OpenCodeEvent.fromJson(Map<String, dynamic> json) {
    
    final eventType = json['type'] as String;
    String? sessionId;
    String? messageId;
    
    // Try multiple field name variations for session ID at root level
    sessionId = json['sessionId'] as String? ?? 
                json['sessionID'] as String? ?? 
                json['session_id'] as String?;
    
    // Try multiple field name variations for message ID at root level
    messageId = json['messageId'] as String? ?? 
                json['messageID'] as String? ?? 
                json['message_id'] as String?;
    
    
    // If not found at root level, check nested properties based on event type
    if (sessionId == null || messageId == null) {
      if (json['properties'] is Map<String, dynamic>) {
        final properties = json['properties'] as Map<String, dynamic>;

        // Check properties.sessionID directly (for session.status, session.idle, etc.)
        sessionId ??= properties['sessionID'] as String? ?? properties['sessionId'] as String?;
        messageId ??= properties['messageID'] as String? ?? properties['messageId'] as String?;

        // For message.updated and session.updated, info is in properties.info
        if (properties['info'] is Map<String, dynamic>) {
          final info = properties['info'] as Map<String, dynamic>;
          sessionId ??= info['sessionID'] as String? ?? info['sessionId'] as String?;
          messageId ??= info['id'] as String?;
        }

        // For message.part.updated events, session info is in properties.part
        if (properties['part'] is Map<String, dynamic>) {
          final part = properties['part'] as Map<String, dynamic>;
          sessionId ??= part['sessionID'] as String? ?? part['sessionId'] as String?;
          messageId ??= part['messageID'] as String? ?? part['messageId'] as String?;
        }

        // For storage.write events, extract session ID from the key path
        if (eventType == 'storage.write' && properties['key'] is String) {
          final key = properties['key'] as String;
          final keyParts = key.split('/');
          if (keyParts.length >= 3 && keyParts[2].startsWith('ses_')) {
            sessionId ??= keyParts[2];
          }
          if (keyParts.length >= 4 && keyParts[3].startsWith('msg_')) {
            messageId ??= keyParts[3];
          }

          if (properties['content'] is Map<String, dynamic>) {
            final content = properties['content'] as Map<String, dynamic>;
            sessionId ??= content['sessionID'] as String? ?? content['sessionId'] as String?;
            messageId ??= content['messageID'] as String? ?? content['messageId'] as String?;
          }
        }
      }
    }
    
    return OpenCodeEvent(
      type: eventType,
      sessionId: sessionId,
      messageId: messageId,
      data: json,  // Store the entire JSON for later processing
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'sessionId': sessionId,
      'messageId': messageId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [type, sessionId, messageId, data, timestamp];
}