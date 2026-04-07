import 'dart:async';
import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../blocs/config/config_cubit.dart';
import '../../blocs/config/config_state.dart';
import '../../models/session_event.dart';
import '../../models/tool_event.dart';
import '../debug_logger.dart';
import 'history_batch_event.dart';
import 'session_activity_event.dart';
import 'space_channel_event.dart';
import 'status_event.dart';

class SpaceChannelService {
  WebSocketChannel? _channel;
  StreamController<SpaceChannelEvent>? _eventController;
  StreamController<HistoryBatchEvent>? _historyController;
  StreamController<SessionActivityEvent>? _activityController;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;
  StreamSubscription? _configSub;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  String? _url;
  int _seq = 0;

  bool get isConnected => _isConnected;
  bool get isActive => _eventController != null && !_eventController!.isClosed;

  Stream<bool> get connectionState => _connectionController.stream;

  Stream<SpaceChannelEvent> get eventStream {
    _eventController ??= StreamController<SpaceChannelEvent>.broadcast();
    return _eventController!.stream;
  }

  Stream<HistoryBatchEvent> get historyBatches {
    _historyController ??= StreamController<HistoryBatchEvent>.broadcast();
    return _historyController!.stream;
  }

  Stream<SessionActivityEvent> get sessionActivity {
    _activityController ??= StreamController<SessionActivityEvent>.broadcast();
    return _activityController!.stream;
  }

  void initialize() {
    final configCubit = GetIt.I<ConfigCubit>();

    _configSub = configCubit.stream.listen((state) {
      if (state is ConfigLoaded) {
        final newUrl = state.claudeCodeWsUrl;
        if (newUrl != _url) {
          debugLogger.info('WS', 'Config changed, reconnecting', newUrl);
          _connectToUrl(newUrl);
        }
      }
    });

    final configState = configCubit.state;
    final wsUrl = configState is ConfigLoaded
        ? configState.claudeCodeWsUrl
        : 'ws://0.0.0.0:${ConfigLoaded.claudeCodePort}/ws';

    _connectToUrl(wsUrl);
  }

  void _connectToUrl(String url) {
    _url = url;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _reconnectAttempts = 0;
    _channel = null;

    _eventController ??= StreamController<SpaceChannelEvent>.broadcast();
    _connectWebSocket();
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

  void _connectWebSocket() {
    if (_url == null) return;

    _reconnectAttempts++;
    debugLogger.info('WS', 'Connecting', 'attempt=$_reconnectAttempts, url=$_url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url!));

      _channel!.ready.then((_) {
        _isConnected = true;
        _reconnectAttempts = 0;
        _connectionController.add(true);
        debugLogger.info('WS', 'Connected');
      }).catchError((error) {
        debugLogger.error('WS', 'Connection failed', error.toString());
        _setDisconnected();
        _reconnect();
      });

      _subscription = _channel!.stream.listen(
        (raw) {
          if (raw is String) handleRawMessage(raw);
        },
        onError: (error) {
          debugLogger.error('WS', 'Stream error', error.toString());
          _setDisconnected();
          if (_eventController?.isClosed == false) {
            _eventController!.addError(error);
          }
          _reconnect();
        },
        onDone: () {
          debugLogger.info('WS', 'Stream done', 'will reconnect');
          _setDisconnected();
          _reconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugLogger.error('WS', 'Connect failed', e.toString());
      _setDisconnected();
      _reconnect();
    }
  }

  void _setDisconnected() {
    if (_isConnected) {
      _isConnected = false;
      _connectionController.add(false);
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

  void handleRawMessage(String raw) {
    debugLogger.debug('WS', 'RAW', raw.length > 200 ? raw.substring(0, 200) : raw);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final json = decoded;
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

      if (typeStr == 'status') {
        _handleStatusEvent(json);
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

    if (_activityController?.isClosed == false) {
      _activityController!.add(SessionActivityEvent.fromSessionEvent(sessionEvent));
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

    if (_activityController?.isClosed == false) {
      _activityController!.add(SessionActivityEvent.fromToolEvent(toolEvent));
    }
  }

  void _handleStatusEvent(Map<String, dynamic> json) {
    final session = json['session'] ?? '';
    final sessionState = json['state'] ?? '';
    if (session.isEmpty || sessionState.isEmpty) return;

    debugLogger.info('WS', 'Status', 'session=$session, state=$sessionState');

    final statusEvent = StatusEvent(session: session, state: sessionState);
    if (_activityController?.isClosed == false) {
      _activityController!.add(SessionActivityEvent.fromStatusEvent(statusEvent));
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

  void dispose() {
    _configSub?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController?.close();
    _historyController?.close();
    _activityController?.close();
    _connectionController.close();
    _isConnected = false;
  }
}
