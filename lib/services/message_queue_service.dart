import 'dart:async';
import 'dart:collection';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../models/opencode_message.dart';
import 'debug_logger.dart';

class QueuedMessage {
  final String messageId;
  final String sessionId;
  final String content;
  final String? imageBase64;
  final String? imageMimeType;
  final DateTime queuedAt;
  final Function(MessageSendStatus) onStatusChange;
  int retryCount;
  DateTime? lastRetryAt;

  QueuedMessage({
    required this.messageId,
    required this.sessionId,
    required this.content,
    this.imageBase64,
    this.imageMimeType,
    required this.queuedAt,
    required this.onStatusChange,
    this.retryCount = 0,
    this.lastRetryAt,
  });
}

/// Service to handle message queuing for offline scenarios and retry logic
class MessageQueueService {
  final ConnectionBloc connectionBloc;
  final SessionBloc sessionBloc;
  
  final Queue<QueuedMessage> _messageQueue = Queue<QueuedMessage>();
  StreamSubscription<ConnectionState>? _connectionSubscription;
  StreamSubscription<SessionState>? _sessionSubscription;
  StreamSubscription? _chatBlocSubscription;
  Timer? _retryTimer;
  
  // Track pending messages waiting for SSE confirmation
  final Map<String, Timer> _pendingMessageTimeouts = {};
  final Map<String, Function(MessageSendStatus)> _pendingCallbacks = {};
  
  static const int maxRetries = 3;
  static const List<Duration> retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  MessageQueueService({
    required this.connectionBloc,
    required this.sessionBloc,
  }) {
    _initConnectionListener();
  }
  
  /// Initialize ChatBloc listener - called after ChatBloc is created
  void initChatBlocListener(dynamic chatBloc) {
    _chatBlocSubscription = chatBloc.stream.listen((chatState) {
      // Check if assistant started streaming (ChatReady with isStreaming: true)
      if (chatState.runtimeType.toString().contains('ChatReady')) {
        final isStreaming = chatState.isStreaming as bool? ?? false;
        if (isStreaming) {
          _handleStreamingStarted();
        }
      }
    });
  }
  
  void _handleStreamingStarted() {
    if (_pendingMessageTimeouts.isNotEmpty) {
      final messageId = _pendingMessageTimeouts.keys.first;
      _markMessageSentViaSSE(messageId);
    }
  }
  
  void _markMessageSentViaSSE(String messageId) {
    if (_pendingMessageTimeouts.containsKey(messageId)) {
      debugLogger.queue('Message confirmed via SSE', 'msgId=$messageId');
      _pendingMessageTimeouts[messageId]?.cancel();
      final callback = _pendingCallbacks[messageId];
      if (callback != null) {
        callback(MessageSendStatus.sent);
      }
      _cleanupPendingMessage(messageId);
    }
  }

  void _markMessageFailed(String messageId, String reason) {
    debugLogger.error('QUEUE', 'Message failed', 'msgId=$messageId, reason=$reason');
    final callback = _pendingCallbacks[messageId];
    if (callback != null) {
      callback(MessageSendStatus.failed);
    }
    _cleanupPendingMessage(messageId);
  }

  void _cleanupPendingMessage(String messageId) {
    _pendingMessageTimeouts.remove(messageId)?.cancel();
    _pendingCallbacks.remove(messageId);
  }

  /// Initialize listeners for connection and session state changes
  void _initConnectionListener() {
    _connectionSubscription = connectionBloc.stream.listen((connectionState) {
      
      if (connectionState is Connected) {
        _processQueue();
      }
    });
    
    _sessionSubscription = sessionBloc.stream.listen((sessionState) {
      if (sessionState is SessionError || sessionState is SessionNotFound) {
        _messageQueue.clear();
      }
    });
  }

  Future<void> sendMessage({
    required String messageId,
    required String sessionId,
    required String content,
    required Function(MessageSendStatus) onStatusChange,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final connectionState = connectionBloc.state;

    if (connectionState is Connected) {
      debugLogger.queue('Sending message', 'msgId=$messageId');
      onStatusChange(MessageSendStatus.sending);
      await _sendMessageDirect(
        messageId,
        sessionId,
        content,
        onStatusChange,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
      );
    } else {
      debugLogger.queue('Queuing message (offline)', 'msgId=$messageId');
      final queuedMessage = QueuedMessage(
        messageId: messageId,
        sessionId: sessionId,
        content: content,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
        queuedAt: DateTime.now(),
        onStatusChange: onStatusChange,
      );

      _messageQueue.add(queuedMessage);
      onStatusChange(MessageSendStatus.queued);
    }
  }

  bool removeFromQueue(String messageId) {
    final initialSize = _messageQueue.length;
    _messageQueue.removeWhere((msg) => msg.messageId == messageId);
    return _messageQueue.length < initialSize;
  }

  Future<void> retryMessage({
    required String messageId,
    required String sessionId,
    required String content,
    required Function(MessageSendStatus) onStatusChange,
  }) async {
    onStatusChange(MessageSendStatus.sending);
    await _sendMessageDirect(messageId, sessionId, content, onStatusChange);
  }

  Future<void> _processQueue() async {
    if (_messageQueue.isEmpty) {
      return;
    }

    debugLogger.queue('Processing queue', 'count=${_messageQueue.length}');
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeFirst();
      debugLogger.queue('Dequeuing message', 'msgId=${message.messageId}');

      message.onStatusChange(MessageSendStatus.sending);
      await _sendMessageDirect(
        message.messageId,
        message.sessionId,
        message.content,
        message.onStatusChange,
        imageBase64: message.imageBase64,
        imageMimeType: message.imageMimeType,
      );

      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _sendMessageDirect(
    String messageId,
    String sessionId,
    String content,
    Function(MessageSendStatus) onStatusChange, {
    String? imageBase64,
    String? imageMimeType,
  }) async {
    debugLogger.queue('HTTP send starting', 'msgId=$messageId, session=$sessionId');
    onStatusChange(MessageSendStatus.sending);

    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_pendingMessageTimeouts.containsKey(messageId)) {
        debugLogger.error('QUEUE', 'Timeout waiting for response', 'msgId=$messageId');
        _markMessageFailed(messageId, 'Timeout - no response from server');
      }
    });

    _pendingMessageTimeouts[messageId] = timeoutTimer;
    _pendingCallbacks[messageId] = onStatusChange;

    final httpFuture = sessionBloc.sendMessageDirect(
      sessionId,
      content,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );

    httpFuture.then((_) {
      debugLogger.queue('HTTP send completed, awaiting SSE confirmation', 'msgId=$messageId');
    }).catchError((error) {
      debugLogger.error('QUEUE', 'HTTP error', 'msgId=$messageId, error=$error');
      if (_pendingMessageTimeouts.containsKey(messageId)) {
        _markMessageFailed(messageId, 'HTTP error: ${error.runtimeType}: $error');
      }
    });
  }

  int get queueSize => _messageQueue.length;

  bool get isConnected => connectionBloc.state is Connected;

  void dispose() {
    _connectionSubscription?.cancel();
    _sessionSubscription?.cancel();
    _chatBlocSubscription?.cancel();
    _retryTimer?.cancel();
    _messageQueue.clear();

    for (final timer in _pendingMessageTimeouts.values) {
      timer.cancel();
    }
    _pendingMessageTimeouts.clear();
    _pendingCallbacks.clear();
  }
}