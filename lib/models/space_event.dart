import 'package:equatable/equatable.dart';

class SpaceEvent extends Equatable {
  final String type;
  final String? sessionId;
  final String? messageId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const SpaceEvent({
    required this.type,
    required this.timestamp,
    this.sessionId,
    this.messageId,
    this.data,
  });

  factory SpaceEvent.fromJson(Map<String, dynamic> json) {
    
    final eventType = json['type'] ?? '';
    String? sessionId;
    String? messageId;

    sessionId = json['sessionId'] ??
                json['sessionID'] ??
                json['session_id'];

    messageId = json['messageId'] ??
                json['messageID'] ??
                json['message_id'];
    
    
    // If not found at root level, check nested properties based on event type
    if (sessionId == null || messageId == null) {
      if (json['properties'] is Map<String, dynamic>) {
        final properties = json['properties'] ?? {};

        sessionId ??= properties['sessionID'] ?? properties['sessionId'];
        messageId ??= properties['messageID'] ?? properties['messageId'];

        if (properties['info'] is Map<String, dynamic>) {
          final info = properties['info'] ?? {};
          sessionId ??= info['sessionID'] ?? info['sessionId'];
          messageId ??= info['id'];
        }

        if (properties['part'] is Map<String, dynamic>) {
          final part = properties['part'] ?? {};
          sessionId ??= part['sessionID'] ?? part['sessionId'];
          messageId ??= part['messageID'] ?? part['messageId'];
        }

        if (eventType == 'storage.write' && properties['key'] is String) {
          final key = properties['key'] ?? '';
          final keyParts = key.split('/');
          if (keyParts.length >= 3 && keyParts[2].startsWith('ses_')) {
            sessionId ??= keyParts[2];
          }
          if (keyParts.length >= 4 && keyParts[3].startsWith('msg_')) {
            messageId ??= keyParts[3];
          }

          if (properties['content'] is Map<String, dynamic>) {
            final content = properties['content'] ?? {};
            sessionId ??= content['sessionID'] ?? content['sessionId'];
            messageId ??= content['messageID'] ?? content['messageId'];
          }
        }
      }
    }
    
    return SpaceEvent(
      type: eventType,
      sessionId: sessionId,
      messageId: messageId,
      data: json,  // Store the entire JSON for later processing
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] ?? '')
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