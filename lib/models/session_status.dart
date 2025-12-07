/// Session status from OpenCode
enum SessionStatusType {
  idle,
  busy,
  retry;

  static SessionStatusType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'idle':
        return SessionStatusType.idle;
      case 'busy':
        return SessionStatusType.busy;
      case 'retry':
        return SessionStatusType.retry;
      default:
        return SessionStatusType.idle;
    }
  }
}

/// Session status information
class SessionStatus {
  final SessionStatusType status;
  final int? retryCount;
  final DateTime? nextRetryTime;

  const SessionStatus({
    required this.status,
    this.retryCount,
    this.nextRetryTime,
  });

  factory SessionStatus.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'idle';
    final retryTimeMs = json['retryTime'] as int?;

    return SessionStatus(
      status: SessionStatusType.fromString(statusStr),
      retryCount: json['retryCount'] as int?,
      nextRetryTime: retryTimeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(retryTimeMs)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      if (retryCount != null) 'retryCount': retryCount,
      if (nextRetryTime != null)
        'retryTime': nextRetryTime!.millisecondsSinceEpoch,
    };
  }

  /// Returns true if the session is currently working
  bool get isWorking => status == SessionStatusType.busy;

  /// Returns true if the session is idle
  bool get isIdle => status == SessionStatusType.idle;

  /// Returns true if the session is retrying
  bool get isRetrying => status == SessionStatusType.retry;

  /// Get a human-readable status message
  String get displayMessage {
    switch (status) {
      case SessionStatusType.idle:
        return 'Idle';
      case SessionStatusType.busy:
        return 'Working...';
      case SessionStatusType.retry:
        if (retryCount != null) {
          return 'Retrying (attempt $retryCount)...';
        }
        return 'Retrying...';
    }
  }

  @override
  String toString() => 'SessionStatus($status, retryCount: $retryCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatus &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          retryCount == other.retryCount &&
          nextRetryTime == other.nextRetryTime;

  @override
  int get hashCode =>
      status.hashCode ^ retryCount.hashCode ^ nextRetryTime.hashCode;
}
