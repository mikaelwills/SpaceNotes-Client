import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/opencode_client.dart';
import '../../services/debug_logger.dart';
import '../../models/session.dart';
import '../config/config_cubit.dart';
import '../config/config_state.dart';

import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final OpenCodeClient openCodeClient;
  final ConfigCubit? configCubit;
  Session? _currentSession;
  bool _isCreatingSession = false; // Guard to prevent concurrent session creation

  static const String _currentSessionKey = 'current_session_id';

  SessionBloc({required this.openCodeClient, this.configCubit}) : super(SessionInitial()) {
    on<CreateSession>(_onCreateSession);
    on<SendMessage>(_onSendMessage);
    on<CancelSessionOperation>(_onCancelSessionOperation);
    on<SessionUpdated>(_onSessionUpdated);
    on<LoadStoredSession>(_onLoadStoredSession);
    on<ValidateSession>(_onValidateSession);
    on<SetCurrentSession>(_onSetCurrentSession);
  }

  Session? get currentSession => _currentSession;

  Future<void> _onCreateSession(
    CreateSession event,
    Emitter<SessionState> emit,
  ) async {
    if (_isCreatingSession) {
      debugLogger.chat('Session: Create skipped (already in progress)');
      return;
    }

    _isCreatingSession = true;
    debugLogger.chat('Session: Creating new session');
    emit(SessionLoading());

    try {
      final session = await openCodeClient.createSession(agent: event.agent);

      _currentSession = session;
      await _persistCurrentSessionId(session.id);
      debugLogger.chat('Session: Created', 'id=${session.id}');
      emit(SessionLoaded(session: session));
    } catch (e, stackTrace) {
      debugLogger.chatError('Session: Create failed', '$e\n$stackTrace');
      emit(SessionError('Failed to create session: ${e.toString()}'));
    } finally {
      _isCreatingSession = false;
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<SessionState> emit,
  ) async {
    // Validate inputs
    if (event.sessionId.trim().isEmpty) {
      emit(const SessionError('Invalid session ID'));
      return;
    }

    if (event.message.trim().isEmpty) {
      emit(const SessionError('Message cannot be empty'));
      return;
    }

    if (_currentSession == null) {
      emit(const SessionError('No active session to send message'));
      return;
    }

    // Validate session ID matches current session
    if (_currentSession!.id != event.sessionId) {
      emit(SessionError(
          'Session ID mismatch: expected ${_currentSession!.id}, got ${event.sessionId}'));
      return;
    }

    emit(MessageSending(_currentSession!));

    // Use provided agent or fall back to default from config
    String? effectiveAgent = event.agent;
    if (effectiveAgent == null && configCubit != null) {
      final configState = configCubit!.state;
      if (configState is ConfigLoaded) {
        effectiveAgent = configState.defaultAgent;
      }
    }

    try {
      await openCodeClient.sendMessage(event.sessionId, event.message, agent: effectiveAgent);

      final updatedSession = _currentSession!.copyWith(
        isActive: true,
        lastActivity: DateTime.now(),
      );
      _currentSession = updatedSession;

      emit(SessionLoaded(session: updatedSession, isActive: true));
    } catch (e, stackTrace) {
      debugLogger.chatError('Session: Send message failed', '$e\n$stackTrace');
      emit(SessionError('Failed to send message: ${e.toString()}'));
    }
  }

  Future<void> _onCancelSessionOperation(
    CancelSessionOperation event,
    Emitter<SessionState> emit,
  ) async {
    if (event.sessionId.trim().isEmpty) {
      emit(const SessionError('Invalid session ID for cancel operation'));
      return;
    }

    debugLogger.chat('Session: Cancelling operation', 'id=${event.sessionId}');
    try {
      await openCodeClient.abortSession(event.sessionId);

      if (_currentSession?.id == event.sessionId) {
        final updatedSession = _currentSession!.copyWith(isActive: false);
        _currentSession = updatedSession;
        emit(SessionLoaded(session: updatedSession, isActive: false));
      }
      debugLogger.chat('Session: Operation cancelled');
    } catch (e, stackTrace) {
      debugLogger.chatError('Session: Cancel failed', '$e\n$stackTrace');
      emit(SessionError('Failed to cancel operation: ${e.toString()}'));
    }
  }

  void _onSessionUpdated(
    SessionUpdated event,
    Emitter<SessionState> emit,
  ) {
    _currentSession = event.session;
    emit(SessionLoaded(session: event.session));
  }

  Future<void> _onLoadStoredSession(
    LoadStoredSession event,
    Emitter<SessionState> emit,
  ) async {
    debugLogger.chat('Session: Loading stored session');
    try {
      final storedSessionId = await _getStoredSessionId();
      if (storedSessionId != null) {
        debugLogger.chat('Session: Found stored ID', 'id=$storedSessionId');
        add(ValidateSession(storedSessionId));
      } else {
        debugLogger.chat('Session: No stored ID, creating new');
        _safelyCreateSession();
      }
    } catch (e) {
      debugLogger.chatError('Session: Load stored failed', e.toString());
      emit(SessionError('Failed to load stored session: ${e.toString()}'));
    }
  }

  Future<void> _onValidateSession(
    ValidateSession event,
    Emitter<SessionState> emit,
  ) async {
    debugLogger.chat('Session: Validating', 'id=${event.sessionId}');
    emit(SessionValidating(event.sessionId));

    try {
      final sessions = await openCodeClient.getSessions();
      debugLogger.chatDebug('Session: Got ${sessions.length} sessions from server');

      Session? session;
      try {
        session = sessions.firstWhere((s) => s.id == event.sessionId);
      } catch (e) {
        session = null;
      }

      if (session != null) {
        _currentSession = session;
        debugLogger.chat('Session: Validated successfully', 'id=${session.id}');
        emit(SessionLoaded(session: session));
      } else {
        debugLogger.chat('Session: Not found on server, creating new', 'id=${event.sessionId}');
        emit(SessionNotFound(event.sessionId));
        await _clearStoredSessionId();
        _safelyCreateSession();
      }
    } catch (e) {
      debugLogger.chatError('Session: Validation failed, creating new', e.toString());
      emit(SessionNotFound(event.sessionId));
      await _clearStoredSessionId();
      _safelyCreateSession();
    }
  }

  Future<void> _onSetCurrentSession(
    SetCurrentSession event,
    Emitter<SessionState> emit,
  ) async {
    debugLogger.chat('Session: Setting current', 'id=${event.sessionId}');
    try {
      final sessions = await openCodeClient.getSessions();
      Session? session;
      try {
        session = sessions.firstWhere((s) => s.id == event.sessionId);
      } catch (e) {
        session = null;
      }

      if (session != null) {
        _currentSession = session;
        await _persistCurrentSessionId(session.id);
        debugLogger.chat('Session: Set successfully', 'id=${session.id}');
        emit(SessionLoaded(session: session));
      } else {
        debugLogger.chatError('Session: Not found', 'id=${event.sessionId}');
        emit(SessionError('Session not found: ${event.sessionId}'));
      }
    } catch (e) {
      debugLogger.chatError('Session: Set failed', e.toString());
      emit(SessionError('Failed to set current session: ${e.toString()}'));
    }
  }

  String? get currentSessionId => _currentSession?.id;

  /// Send message directly without using events - for MessageQueueService
  /// Returns Future that completes on success or throws on error
  Future<void> sendMessageDirect(
    String sessionId,
    String message, {
    String? agent,
    String? imageBase64,
    String? imageMimeType,
  }) async {

    // Same validation logic as _onSendMessage
    if (sessionId.trim().isEmpty) {
      throw Exception('Invalid session ID');
    }

    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    if (_currentSession == null) {
      throw Exception('No active session to send message');
    }

    // Validate session ID matches current session
    if (_currentSession!.id != sessionId) {
      throw Exception(
          'Session ID mismatch: expected ${_currentSession!.id}, got $sessionId');
    }

    // Use provided agent or fall back to default from config
    String? effectiveAgent = agent;
    if (effectiveAgent == null && configCubit != null) {
      final configState = configCubit!.state;
      if (configState is ConfigLoaded) {
        effectiveAgent = configState.defaultAgent;
      }
    }

    try {
      await openCodeClient.sendMessage(
        sessionId,
        message,
        agent: effectiveAgent,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
      );

      // Update session to active state (same as event handler)
      final updatedSession = _currentSession!.copyWith(
        isActive: true,
        lastActivity: DateTime.now(),
      );
      _currentSession = updatedSession;

      // Note: No state emission - this is for direct calls only
      // The MessageQueueService will handle status via callbacks

    } catch (e) {
      rethrow; // Re-throw for MessageQueueService to handle
    }
  }

  Future<void> _persistCurrentSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSessionKey, sessionId);
      debugLogger.chatDebug('Session: Persisted ID', 'id=$sessionId');
    } catch (e) {
      debugLogger.chatError('Session: Failed to persist ID', e.toString());
    }
  }

  Future<String?> _getStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSessionKey);
    } catch (e) {
      debugLogger.chatError('Session: Failed to get stored ID', e.toString());
      return null;
    }
  }

  Future<void> _clearStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentSessionKey);
      debugLogger.chatDebug('Session: Cleared stored ID');
    } catch (e) {
      debugLogger.chatError('Session: Failed to clear stored ID', e.toString());
    }
  }

  /// Safely creates a session only if one isn't already being created
  void _safelyCreateSession() {
    if (!_isCreatingSession) {
      String? defaultAgent;
      if (configCubit != null) {
        final configState = configCubit!.state;
        if (configState is ConfigLoaded) {
          defaultAgent = configState.defaultAgent;
        }
      }
      add(CreateSession(agent: defaultAgent));
    }
  }
}
