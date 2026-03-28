import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/session_event.dart';
import '../models/tool_event.dart';
import 'debug_logger.dart';

enum SpaceChannelEventType { msg, edit, permissionRequest }

enum SpaceChannelSourceType { session, webhook, unknown }

class SpaceChannelEvent {
  final SpaceChannelEventType type;
  final String id;
  final String? from;
  final String? text;
  final int? ts;
  final String? replyTo;
  final SpaceChannelFile? file;
  final SpaceChannelSourceType? sourceType;
  final String? project;
  final String? task;
  final String? session;
  final Map<String, dynamic>? permissionData;

  const SpaceChannelEvent({
    required this.type,
    required this.id,
    this.from,
    this.text,
    this.ts,
    this.replyTo,
    this.file,
    this.sourceType,
    this.project,
    this.task,
    this.session,
    this.permissionData,
  });

  factory SpaceChannelEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] ?? 'msg';

    SpaceChannelSourceType? sourceType;
    if (typeStr == 'webhook') {
      sourceType = SpaceChannelSourceType.webhook;
    } else {
      sourceType = SpaceChannelSourceType.session;
    }

    final eventType = (typeStr == 'edit')
        ? SpaceChannelEventType.edit
        : SpaceChannelEventType.msg;

    return SpaceChannelEvent(
      type: eventType,
      id: json['id'] ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      from: json['from'] ?? '',
      text: json['text'] ?? '',
      ts: json['ts'],
      replyTo: json['replyTo'] ?? '',
      file: json['file'] != null
          ? SpaceChannelFile.fromJson(json['file'] ?? {})
          : null,
      sourceType: sourceType,
      project: json['project'] ?? json['source'] ?? '',
      task: json['task'] ?? '',
      session: json['session'] ?? '',
    );
  }

}

class SpaceChannelFile {
  final String url;
  final String name;

  const SpaceChannelFile({required this.url, required this.name});

  factory SpaceChannelFile.fromJson(Map<String, dynamic> json) {
    return SpaceChannelFile(
      url: json['url'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class HistoryBatchEvent {
  final String session;
  final List<SpaceChannelEvent> events;

  const HistoryBatchEvent({required this.session, required this.events});
}

class SpaceChannelService {
  static const int _maxToolEventsPerSession = 50;

  WebSocketChannel? _channel;
  StreamController<SpaceChannelEvent>? _eventController;
  StreamController<ToolEvent>? _toolEventController;
  StreamController<SessionEvent>? _sessionEventController;
  StreamController<HistoryBatchEvent>? _historyController;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  String? _url;
  int _seq = 0;
  final Map<String, List<ToolEvent>> _toolEventsBySession = {};

  bool get isConnected => _isConnected;
  bool get isActive => _eventController != null && !_eventController!.isClosed;

  Stream<ToolEvent> get toolEvents {
    _toolEventController ??= StreamController<ToolEvent>.broadcast();
    return _toolEventController!.stream;
  }

  Stream<SessionEvent> get sessionEvents {
    _sessionEventController ??= StreamController<SessionEvent>.broadcast();
    return _sessionEventController!.stream;
  }

  Stream<HistoryBatchEvent> get historyBatches {
    _historyController ??= StreamController<HistoryBatchEvent>.broadcast();
    return _historyController!.stream;
  }

  List<ToolEvent> getToolEventsForSession(String session) {
    return List.unmodifiable(_toolEventsBySession[session] ?? []);
  }

  Stream<SpaceChannelEvent> get eventStream {
    _eventController ??= StreamController<SpaceChannelEvent>.broadcast();
    return _eventController!.stream;
  }

  Stream<SpaceChannelEvent> eventsForSession(String sessionId) {
    _eventController ??= StreamController<SpaceChannelEvent>.broadcast();
    return _eventController!.stream.where((e) => e.session == sessionId);
  }

  void sendMessageToSession(String sessionId, String text) {
    if (_channel == null) return;
    final id = 'u${DateTime.now().millisecondsSinceEpoch}-${++_seq}';
    debugLogger.info('WS', 'SendToSession', 'session=$sessionId, id=$id');
    _channel!.sink.add(jsonEncode({
      'type': 'chat',
      'id': id,
      'text': text,
      'session': sessionId,
    }));
  }

  Stream<SpaceChannelEvent> connect(String url) {
    _url = url;

    if (_eventController != null && !_eventController!.isClosed) {
      return _eventController!.stream;
    }

    _eventController = StreamController<SpaceChannelEvent>.broadcast();
    _connectWebSocket();
    return _eventController!.stream;
  }

  void _connectWebSocket() {
    if (_url == null) return;

    _reconnectAttempts++;
    debugLogger.info('WS', 'Connecting', 'attempt=$_reconnectAttempts, url=$_url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url!));

      _channel!.ready.then((_) {
        _isConnected = true;
        _reconnectAttempts = 0;
        debugLogger.info('WS', 'Connected');
      }).catchError((error) {
        debugLogger.error('WS', 'Connection failed', error.toString());
        _isConnected = false;
        _reconnect();
      });

      _subscription = _channel!.stream.listen(
        (raw) {
          handleRawMessage(raw as String);
        },
        onError: (error) {
          debugLogger.error('WS', 'Stream error', error.toString());
          _isConnected = false;
          if (_eventController?.isClosed == false) {
            _eventController!.addError(error);
          }
          _reconnect();
        },
        onDone: () {
          debugLogger.info('WS', 'Stream done', 'will reconnect');
          _isConnected = false;
          _reconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugLogger.error('WS', 'Connect failed', e.toString());
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    if (_url == null) return;

    _subscription?.cancel();
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 30));

    debugLogger.info('WS', 'Reconnect scheduled', 'delay=${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        _connectWebSocket();
      }
    });
  }

  void sendPermissionResponse(String session, String requestId, String behavior) {
    if (_channel == null) return;
    debugLogger.info('WS', 'Permission response', 'id=$requestId, behavior=$behavior');
    _channel!.sink.add(jsonEncode({
      'type': 'permission_response',
      'session': session,
      'request_id': requestId,
      'behavior': behavior,
    }));
  }

  void sendMessage(String text) {
    if (_channel == null) return;

    final id = 'u${DateTime.now().millisecondsSinceEpoch}-${++_seq}';
    debugLogger.info('WS', 'Sending', 'id=$id, text=${text.length > 50 ? text.substring(0, 50) : text}');
    _channel!.sink.add(jsonEncode({'type': 'chat', 'id': id, 'text': text}));
  }

  void handleRawMessage(String raw) {
    debugLogger.debug('WS', 'RAW', raw.length > 200 ? raw.substring(0, 200) : raw);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final typeStr = json['type'] ?? '';

      if (typeStr == 'tool_event') {
        _handleToolEvent(json);
        return;
      }

      if (typeStr == 'session') {
        _handleSessionEvent(json);
        return;
      }

      if (typeStr == 'permission_request') {
        _handlePermissionRequest(json);
        return;
      }

      if (typeStr == 'history_batch') {
        _handleHistoryBatch(json);
        return;
      }

      final event = SpaceChannelEvent.fromJson(json);
      if (_eventController?.isClosed == false) {
        _eventController!.add(event);
      }
    } catch (e) {
      debugLogger.error('WS', 'Parse error', e.toString());
    }
  }

  void _handleSessionEvent(Map<String, dynamic> json) {
    final sessionEvent = SessionEvent.fromJson(json);
    debugLogger.info('WS', 'Session event', 'action=${sessionEvent.action}, session=${sessionEvent.session}');

    if (_sessionEventController?.isClosed == false) {
      _sessionEventController!.add(sessionEvent);
    }
  }

  void _handlePermissionRequest(Map<String, dynamic> json) {
    final requestId = json['request_id'] ?? json['id'] ?? 'perm-${DateTime.now().millisecondsSinceEpoch}';
    final toolName = json['tool_name'] ?? json['permission'] ?? '';
    final description = json['description'] ?? '';
    final inputPreview = json['input_preview'] ?? '';
    final session = json['session'] ?? '';

    debugLogger.info('WS', 'Permission request', 'id=$requestId, tool=$toolName');

    final event = SpaceChannelEvent(
      type: SpaceChannelEventType.permissionRequest,
      id: requestId,
      from: 'assistant',
      text: '$toolName: $description',
      sourceType: SpaceChannelSourceType.session,
      session: session,
      project: json['project'] ?? '',
      task: json['task'] ?? '',
      permissionData: {
        'request_id': requestId,
        'tool_name': toolName,
        'description': description,
        'input_preview': inputPreview,
        'pending_permission': true,
        'raw': json,
      },
    );

    if (_eventController?.isClosed == false) {
      _eventController!.add(event);
    }
  }

  void _handleToolEvent(Map<String, dynamic> json) {
    final toolEvent = ToolEvent.fromJson(json);
    debugLogger.info('WS', 'Tool event', 'tool=${toolEvent.tool}, session=${toolEvent.session}');

    final session = toolEvent.session;
    final events = _toolEventsBySession.putIfAbsent(session, () => []);
    events.add(toolEvent);
    if (events.length > _maxToolEventsPerSession) {
      events.removeRange(0, events.length - _maxToolEventsPerSession);
    }

    if (_toolEventController?.isClosed == false) {
      _toolEventController!.add(toolEvent);
    }
  }

  void _handleHistoryBatch(Map<String, dynamic> json) {
    final String session = json['session'] ?? '';
    final List<dynamic> messages = json['messages'] ?? [];
    if (session.isEmpty || messages.isEmpty) return;

    debugLogger.info('WS', 'History batch', 'session=$session, count=${messages.length}');

    final events = <SpaceChannelEvent>[];
    for (final m in messages) {
      if (m is Map<String, dynamic>) {
        events.add(SpaceChannelEvent.fromJson(m));
      }
    }

    if (_historyController?.isClosed == false) {
      _historyController!.add(HistoryBatchEvent(session: session, events: events));
    }
  }

  void restartConnection() {
    debugLogger.info('WS', 'Restart: Cleaning up');
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    _isConnected = false;
    _reconnectAttempts = 0;
    _channel = null;
    _toolEventsBySession.clear();

    _connectWebSocket();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController?.close();
    _toolEventController?.close();
    _sessionEventController?.close();
    _historyController?.close();
    _isConnected = false;
  }
}
