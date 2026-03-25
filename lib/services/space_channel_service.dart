import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/tool_event.dart';
import 'debug_logger.dart';

enum SpaceChannelEventType { msg, edit }

enum SpaceChannelSourceType { master, worker, webhook, unknown }

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
  });

  factory SpaceChannelEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'msg';

    SpaceChannelSourceType? sourceType;
    if (typeStr == 'worker_reply') {
      sourceType = SpaceChannelSourceType.worker;
    } else if (typeStr == 'webhook') {
      sourceType = SpaceChannelSourceType.webhook;
    } else if (json['sourceType'] != null) {
      sourceType = _parseSourceType(json['sourceType'] as String);
    }

    final eventType = (typeStr == 'edit')
        ? SpaceChannelEventType.edit
        : SpaceChannelEventType.msg;

    return SpaceChannelEvent(
      type: eventType,
      id: json['id'] as String,
      from: json['from'] as String?,
      text: json['text'] as String?,
      ts: json['ts'] as int?,
      replyTo: json['replyTo'] as String?,
      file: json['file'] != null
          ? SpaceChannelFile.fromJson(json['file'] as Map<String, dynamic>)
          : null,
      sourceType: sourceType,
      project: json['project'] as String?,
      task: json['task'] as String?,
      session: json['session'] as String?,
    );
  }

  static SpaceChannelSourceType _parseSourceType(String value) {
    switch (value) {
      case 'master':
        return SpaceChannelSourceType.master;
      case 'worker':
        return SpaceChannelSourceType.worker;
      case 'webhook':
        return SpaceChannelSourceType.webhook;
      default:
        return SpaceChannelSourceType.unknown;
    }
  }
}

class SpaceChannelFile {
  final String url;
  final String name;

  const SpaceChannelFile({required this.url, required this.name});

  factory SpaceChannelFile.fromJson(Map<String, dynamic> json) {
    return SpaceChannelFile(
      url: json['url'] as String,
      name: json['name'] as String,
    );
  }
}

class SpaceChannelService {
  static const int _maxToolEventsPerSession = 50;

  WebSocketChannel? _channel;
  StreamController<SpaceChannelEvent>? _eventController;
  StreamController<ToolEvent>? _toolEventController;
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

  List<ToolEvent> getToolEventsForSession(String session) {
    return List.unmodifiable(_toolEventsBySession[session] ?? []);
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
    if (_eventController == null || _eventController!.isClosed) return;

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

  void sendMessage(String text) {
    if (_channel == null) return;

    final id = 'u${DateTime.now().millisecondsSinceEpoch}-${++_seq}';
    debugLogger.info('WS', 'Sending', 'id=$id, text=${text.length > 50 ? text.substring(0, 50) : text}');
    _channel!.sink.add(jsonEncode({'type': 'chat', 'id': id, 'text': text}));
  }

  void handleRawMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final typeStr = json['type'] as String? ?? '';

      if (typeStr == 'tool_event') {
        _handleToolEvent(json);
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

  void restartConnection() {
    debugLogger.info('WS', 'Restart: Cleaning up');
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.close();
    }

    _isConnected = false;
    _reconnectAttempts = 0;
    _eventController = null;
    _channel = null;
    _toolEventsBySession.clear();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController?.close();
    _toolEventController?.close();
    _isConnected = false;
  }
}
