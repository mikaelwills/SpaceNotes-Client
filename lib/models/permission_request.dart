/// Permission request from OpenCode server
///
/// Represents a permission request that requires user approval
/// before OpenCode can perform a potentially dangerous operation.
class PermissionRequest {
  final String id;
  final String type;
  final String? pattern;
  final String sessionId;
  final String messageId;
  final String? callId;
  final String title;
  final Map<String, dynamic> metadata;
  final DateTime created;

  const PermissionRequest({
    required this.id,
    required this.type,
    this.pattern,
    required this.sessionId,
    required this.messageId,
    this.callId,
    required this.title,
    required this.metadata,
    required this.created,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    final timeData = json['time'] as Map<String, dynamic>?;
    final created = timeData != null && timeData['created'] != null
        ? DateTime.fromMillisecondsSinceEpoch(timeData['created'] as int)
        : DateTime.now();

    return PermissionRequest(
      id: json['id'] as String,
      type: json['type'] as String,
      pattern: json['pattern'] as String?,
      sessionId: json['sessionID'] as String,
      messageId: json['messageID'] as String,
      callId: json['callID'] as String?,
      title: json['title'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      created: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (pattern != null) 'pattern': pattern,
      'sessionID': sessionId,
      'messageID': messageId,
      if (callId != null) 'callID': callId,
      'title': title,
      'metadata': metadata,
      'time': {
        'created': created.millisecondsSinceEpoch,
      },
    };
  }

  /// Get a human-readable description of what permission is being requested
  String get description {
    switch (type) {
      case 'bash':
        return 'Execute shell command: ${pattern ?? 'unknown'}';
      case 'edit':
        return 'Edit file: ${pattern ?? 'unknown'}';
      case 'write':
        return 'Write to file: ${pattern ?? 'unknown'}';
      case 'webfetch':
        return 'Fetch from URL: ${pattern ?? 'unknown'}';
      case 'doom_loop':
        return 'Continue operation (possible infinite loop detected)';
      case 'external_directory':
        return 'Access directory outside project: ${pattern ?? 'unknown'}';
      default:
        return title;
    }
  }

  /// Returns true if this is a dangerous operation
  bool get isDangerous {
    if (type == 'bash') {
      final cmd = pattern?.toLowerCase() ?? '';
      return cmd.contains('rm ') ||
          cmd.contains('delete') ||
          cmd.contains('format') ||
          cmd.startsWith('sudo ') ||
          cmd.contains('git push');
    }
    return type == 'edit' || type == 'external_directory';
  }
}

/// Permission response type
enum PermissionResponse {
  /// Allow this operation once
  once('once'),

  /// Always allow this type of operation
  always('always'),

  /// Reject/deny this operation
  reject('reject');

  const PermissionResponse(this.value);
  final String value;
}
