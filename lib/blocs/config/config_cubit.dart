import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_state.dart';
import '../config/web_hostname_service.dart';

class ConfigCubit extends Cubit<ConfigState> {
  static const String _defaultServerIp = '0.0.0.0';
  static const int _defaultPort = 5053;
  static const String _defaultAgentName = 'spacenotes';

  ConfigCubit() : super(ConfigLoading());

  /// Initialize configuration from SharedPreferences
  Future<void> initialize() async {
    try {
      emit(ConfigLoading());

      final prefs = await SharedPreferences.getInstance();
      var savedIP = prefs.getString('server_ip');

      if (savedIP == null || savedIP == _defaultServerIp || savedIP.isEmpty) {
        final spaceNotesHost = prefs.getString('spacenotes_host');
        if (spaceNotesHost != null && spaceNotesHost.isNotEmpty) {
          final parts = spaceNotesHost.split(':');
          if (parts.isNotEmpty && parts[0].isNotEmpty) {
            savedIP = parts[0];
          }
        }
      }

      if ((savedIP == null || savedIP == _defaultServerIp || savedIP.isEmpty) && kIsWeb) {
        final webHostname = WebHostnameService.getCurrentHostname();
        if (webHostname != null) {
          savedIP = webHostname;
        }
      }

      savedIP ??= _defaultServerIp;
      final port = prefs.getInt('server_port') ?? _defaultPort;
      final selectedProviderID = prefs.getString('selected_provider_id');
      final selectedModelID = prefs.getString('selected_model_id');
      final defaultAgent = prefs.getString('default_agent') ?? _defaultAgentName;
      final baseUrl = 'http://$savedIP:$port';

      emit(ConfigLoaded(
        baseUrl: baseUrl,
        serverIp: savedIP,
        port: port,
        selectedProviderID: selectedProviderID,
        selectedModelID: selectedModelID,
        defaultAgent: defaultAgent,
      ));
    } catch (e) {
      emit(ConfigError('Failed to initialize config: ${e.toString()}'));
    }
  }

  /// Update the server IP and port
  Future<void> updateServer(String serverIp, {int? port}) async {
    try {
      final currentState = state;
      if (currentState is! ConfigLoaded) {
        emit(const ConfigError(
            'Cannot update server when config is not loaded'));
        return;
      }

      final newPort = port ?? currentState.port;
      final newBaseUrl = 'http://$serverIp:$newPort';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', serverIp);
      await prefs.setInt('server_port', newPort);

      emit(ConfigLoaded(
        baseUrl: newBaseUrl,
        serverIp: serverIp,
        port: newPort,
        selectedProviderID: currentState.selectedProviderID,
        selectedModelID: currentState.selectedModelID,
      ));
    } catch (e) {
      emit(ConfigError('Failed to update server: ${e.toString()}'));
    }
  }

  /// Reset to default configuration
  Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
      await prefs.remove('selected_provider_id');
      await prefs.remove('selected_model_id');

      const baseUrl = 'http://$_defaultServerIp:$_defaultPort';

      emit(const ConfigLoaded(
        baseUrl: baseUrl,
        serverIp: _defaultServerIp,
        port: _defaultPort,
        selectedProviderID: null,
        selectedModelID: null,
      ));
    } catch (e) {
      emit(ConfigError('Failed to reset config: ${e.toString()}'));
    }
  }

  /// Update the selected provider and model
  Future<void> updateProvider(String providerID, String modelID) async {
    try {
      final currentState = state;
      if (currentState is! ConfigLoaded) {
        emit(const ConfigError(
            'Cannot update provider when config is not loaded'));
        return;
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_provider_id', providerID);
      await prefs.setString('selected_model_id', modelID);

      emit(currentState.copyWith(
        selectedProviderID: providerID,
        selectedModelID: modelID,
      ));
    } catch (e) {
      emit(ConfigError('Failed to update provider: ${e.toString()}'));
    }
  }

  /// Update the default agent
  Future<void> updateDefaultAgent(String? agent) async {
    try {
      final currentState = state;
      if (currentState is! ConfigLoaded) {
        emit(const ConfigError(
            'Cannot update agent when config is not loaded'));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (agent != null && agent.isNotEmpty) {
        await prefs.setString('default_agent', agent);
      } else {
        await prefs.remove('default_agent');
      }

      emit(currentState.copyWith(defaultAgent: agent));
    } catch (e) {
      emit(ConfigError('Failed to update agent: ${e.toString()}'));
    }
  }

  /// Get current base URL (for backward compatibility)
  String get baseUrl {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.baseUrl;
    }
    return 'http://$_defaultServerIp:$_defaultPort';
  }

  /// Get current server IP
  String get serverIp {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.serverIp;
    }
    return _defaultServerIp;
  }

  /// Get current port
  int get port {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.port;
    }
    return _defaultPort;
  }

  /// Get default agent
  String? get defaultAgent {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.defaultAgent;
    }
    return null;
  }

  // Static endpoints (unchanged)
  static const String sseEndpoint = '/event';
  static const String sessionEndpoint = '/session';
  static const String configEndpoint = '/config';

  // Dynamic endpoints (require parameters)
  static String messageEndpoint(String sessionId) =>
      '/session/$sessionId/message';
  static String abortEndpoint(String sessionId) => '/session/$sessionId/abort';
  static String sessionByIdEndpoint(String sessionId) => '/session/$sessionId';

  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;

  // SSE settings
  static const Duration sseTimeout = Duration(seconds: 120);
  static const Map<String, String> sseHeaders = {
    'Accept': 'text/event-stream',
    'Cache-Control': 'no-cache',
  };

  // HTTP headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
