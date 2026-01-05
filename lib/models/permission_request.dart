/// Permission request from OpenCode server (v1.1.1+)
///
/// Represents a permission request that requires user approval
/// before OpenCode can perform a potentially dangerous operation.
class PermissionRequest {
  final String id;
  final String permission;
  final List<String> patterns;
  final String sessionId;
  final String messageId;
  final String? callId;
  final List<String> always;
  final Map<String, dynamic> metadata;
  final DateTime created;

  const PermissionRequest({
    required this.id,
    required this.permission,
    required this.patterns,
    required this.sessionId,
    required this.messageId,
    this.callId,
    required this.always,
    required this.metadata,
    required this.created,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    final tool = json['tool'];
    final timeData = json['time'];
    final created = timeData is Map && timeData['created'] != null
        ? DateTime.fromMillisecondsSinceEpoch(timeData['created'] ?? 0)
        : DateTime.now();

    return PermissionRequest(
      id: json['id'] ?? '',
      permission: json['permission'] ?? '',
      patterns: (json['patterns'] as List?)?.cast<String>() ?? [],
      sessionId: json['sessionID'] ?? '',
      messageId: (tool is Map ? tool['messageID'] : null) ?? '',
      callId: tool is Map ? tool['callID'] : null,
      always: (json['always'] as List?)?.cast<String>() ?? [],
      metadata: json['metadata'] ?? {},
      created: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'permission': permission,
      'patterns': patterns,
      'sessionID': sessionId,
      'tool': {
        'messageID': messageId,
        if (callId != null) 'callID': callId,
      },
      'always': always,
      'metadata': metadata,
      'time': {
        'created': created.millisecondsSinceEpoch,
      },
    };
  }

  /// Get a human-readable title for this permission type
  String get title {
    switch (permission) {
      case 'bash':
        return 'Shell Command';
      case 'edit':
        return 'File Edit';
      case 'write':
        return 'File Write';
      case 'webfetch':
        return 'Web Request';
      case 'doom_loop':
        return 'Loop Protection';
      case 'external_directory':
        return 'External Directory';
      default:
        return permission;
    }
  }

  /// Get a human-readable description of what permission is being requested
  String get description {
    final patternStr = patterns.isNotEmpty ? patterns.join(', ') : 'unknown';
    switch (permission) {
      case 'bash':
        return 'Execute shell command: $patternStr';
      case 'edit':
        return 'Edit file: $patternStr';
      case 'write':
        return 'Write to file: $patternStr';
      case 'webfetch':
        return 'Fetch from URL: $patternStr';
      case 'doom_loop':
        return 'Continue operation (possible infinite loop detected)';
      case 'external_directory':
        return 'Access directory outside project: $patternStr';
      default:
        return '$permission: $patternStr';
    }
  }

  /// Returns true if this is a dangerous operation
  bool get isDangerous {
    if (permission == 'bash') {
      final cmd = patterns.join(' ').toLowerCase();
      return cmd.contains('rm ') ||
          cmd.contains('delete') ||
          cmd.contains('format') ||
          cmd.startsWith('sudo ') ||
          cmd.contains('git push');
    }
    return permission == 'edit' || permission == 'external_directory';
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
