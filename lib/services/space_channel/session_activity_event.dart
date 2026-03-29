import '../../models/session_event.dart';
import '../../models/tool_event.dart';
import 'status_event.dart';

enum SessionActivityType { connected, disconnected, toolUse, status }

class SessionActivityEvent {
  final SessionActivityType type;
  final String session;
  final SessionEvent? sessionEvent;
  final ToolEvent? toolEvent;
  final StatusEvent? statusEvent;

  const SessionActivityEvent._({
    required this.type,
    required this.session,
    this.sessionEvent,
    this.toolEvent,
    this.statusEvent,
  });

  factory SessionActivityEvent.fromSessionEvent(SessionEvent event) {
    return SessionActivityEvent._(
      type: event.isConnected
          ? SessionActivityType.connected
          : SessionActivityType.disconnected,
      session: event.session,
      sessionEvent: event,
    );
  }

  factory SessionActivityEvent.fromToolEvent(ToolEvent event) {
    return SessionActivityEvent._(
      type: SessionActivityType.toolUse,
      session: event.session,
      toolEvent: event,
    );
  }

  factory SessionActivityEvent.fromStatusEvent(StatusEvent event) {
    return SessionActivityEvent._(
      type: SessionActivityType.status,
      session: event.session,
      statusEvent: event,
    );
  }
}
