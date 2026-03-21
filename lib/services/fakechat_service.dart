import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'debug_logger.dart';

enum FakechatEventType { msg, edit }

class FakechatEvent {
  final FakechatEventType type;
  final String id;
  final String? from;
  final String? text;
  final int? ts;
  final String? replyTo;
  final FakechatFile? file;

  const FakechatEvent({
    required this.type,
    required this.id,
    this.from,
    this.text,
    this.ts,
    this.replyTo,
    this.file,
  });

  factory FakechatEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'msg';
    return FakechatEvent(
      type: typeStr == 'edit' ? FakechatEventType.edit : FakechatEventType.msg,
      id: json['id'] as String,
      from: json['from'] as String?,
      text: json['text'] as String?,
      ts: json['ts'] as int?,
      replyTo: json['replyTo'] as String?,
      file: json['file'] != null
          ? FakechatFile.fromJson(json['file'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FakechatFile {
  final String url;
  final String name;

  const FakechatFile({required this.url, required this.name});

  factory FakechatFile.fromJson(Map<String, dynamic> json) {
    return FakechatFile(
      url: json['url'] as String,
      name: json['name'] as String,
    );
  }
}

class FakechatService {
  WebSocketChannel? _channel;
  StreamController<FakechatEvent>? _eventController;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  String? _url;
  int _seq = 0;

  bool get isConnected => _isConnected;
  bool get isActive => _eventController != null && !_eventController!.isClosed;

  Stream<FakechatEvent> connect(String url) {
    _url = url;

    if (_eventController != null && !_eventController!.isClosed) {
      return _eventController!.stream;
    }

    _eventController = StreamController<FakechatEvent>.broadcast();
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
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = FakechatEvent.fromJson(json);
            if (_eventController?.isClosed == false) {
              _eventController!.add(event);
            }
          } catch (e) {
            debugLogger.error('WS', 'Parse error', e.toString());
          }
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
    _channel!.sink.add(jsonEncode({'id': id, 'text': text}));
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
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController?.close();
    _isConnected = false;
  }
}
