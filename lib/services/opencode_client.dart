import 'dart:convert';
import 'package:http/http.dart' as http;
import '../blocs/config/config_cubit.dart';
import '../models/session.dart';
import '../models/opencode_message.dart';
import '../models/message_part.dart';
import '../models/provider.dart';
import '../models/permission_request.dart';
import '../models/session_status.dart';

class OpenCodeClient {
  final http.Client _client = http.Client();
  final ConfigCubit _configCubit;
  String? _providerID;
  String? _modelID;
  List<String> _availableAgents = [];

  OpenCodeClient({required ConfigCubit configCubit}) : _configCubit = configCubit;

  List<String> get availableAgents => _availableAgents;

  String get _baseUrl => _configCubit.baseUrl;

  String? get providerID => _providerID;
  String? get modelID => _modelID;
  String get modelDisplayName {
    if (_modelID == null || _providerID == null) {
      return 'Unknown Model';
    }
    
    // Format provider name (e.g., "anthropic" -> "Anthropic")
    String formattedProvider = _providerID!.split('-').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
    
    // Format model name (e.g., "claude-3-5-sonnet-20241022" -> "Claude Sonnet 4")
    String formattedModel = _formatModelName(_modelID!);
    
    return '$formattedProvider $formattedModel';
  }
  
  String _formatModelName(String modelId) {
    // Remove date patterns (numbers with 8+ digits)
    String cleaned = modelId.replaceAll(RegExp(r'-?\d{8,}'), '');
    
    // Handle specific model patterns
    if (cleaned.contains('claude')) {
      // Extract version numbers and model type
      final parts = cleaned.split('-');
      String result = 'Claude';
      
      // Look for version numbers and model type
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part == 'claude') continue;
        
        // Handle version numbers (3, 5, etc.)
        if (RegExp(r'^\d+$').hasMatch(part)) {
          // Skip adding version numbers for now, we'll handle them specially
          continue;
        }
        
        // Handle model types
        if (part == 'sonnet' || part == 'haiku' || part == 'opus') {
          result += ' ${part[0].toUpperCase()}${part.substring(1)}';
        }
      }
      
      // Add version number at the end (extract the highest single digit)
      final versionMatch = RegExp(r'-(\d+)-').firstMatch(modelId);
      if (versionMatch != null) {
        final version = versionMatch.group(1);
        if (version != null && version.length == 1) {
          result += ' $version';
        }
      }
      
      return result;
    }
    
    // Default formatting for other models
    return cleaned
        .split('-')
        .where((part) => part.isNotEmpty && !RegExp(r'^\d+$').hasMatch(part))
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> getProviders() async {
    try {
      final uri = Uri.parse('$_baseUrl/config');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? modelString = data['model'];
        if (modelString != null && modelString.contains('/')) {
          final parts = modelString.split('/');
          _providerID = parts[0];
          _modelID = parts[1];
        } else {
          throw Exception('Invalid model format in config: $modelString');
        }
      } else {
        throw Exception('Failed to get providers: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('No route to host') || e.toString().contains('Connection failed')) {
        throw Exception('Cannot connect to OpenCode server at $_baseUrl. Please check:\n'
            '1. Tailscale is running and connected\n'
            '2. OpenCode server is running at $_baseUrl\n'
            '3. Network connectivity is available');
      }

      throw Exception('Failed to get providers: $e');
    }
  }

  Future<bool> ping() async {
    try {
      final uri = Uri.parse('$_baseUrl/config');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Session>> getSessions() async {
    try {
      final uri = Uri.parse('$_baseUrl/session');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final sessions = data.map((json) => Session.fromJson(json)).toList();
        return sessions;
      } else {
        throw Exception('Failed to load sessions: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Session> createSession({String? agent}) async {
    try {
      final uri = Uri.parse('$_baseUrl/session');
      final Map<String, dynamic> body = {};
      if (agent != null) {
        body['agent'] = agent;
      }
      final requestBody = json.encode(body);

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final sessionData = json.decode(response.body);
        final session = Session.fromJson(sessionData);
        return session;
      } else {
        throw Exception('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> switchAgent(String sessionId, String agent) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/agent');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'agent': agent}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to switch agent: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<OpenCodeMessage> sendMessage(
    String sessionId,
    String message, {
    String? agent,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/message');
      final List<Map<String, dynamic>> parts = [
        {'type': 'text', 'text': message}
      ];

      if (imageBase64 != null && imageMimeType != null) {
        parts.add({
          'type': 'file',
          'mime': imageMimeType,
          'url': 'data:$imageMimeType;base64,$imageBase64',
        });
      }

      final Map<String, dynamic> body = {
        'parts': parts,
      };
      if (_providerID != null && _modelID != null) {
        body['model'] = {
          'providerID': _providerID,
          'modelID': _modelID,
        };
      }
      if (_availableAgents.isNotEmpty) {
        body['agent'] = _availableAgents.first;
      }
      final requestBody = json.encode(body);

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return OpenCodeMessage(
            id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: sessionId,
            role: 'user',
            created: DateTime.now(),
            parts: [MessagePart(id: 'part_${DateTime.now().millisecondsSinceEpoch}', type: 'text', content: message)],
          );
        }

        final messageData = json.decode(response.body);

        if (messageData.containsKey('name') && messageData.containsKey('data')) {
          final errorName = messageData['name'];
          final errorMessage = messageData['data']['message'];
          throw Exception('Failed to send message: $errorName - $errorMessage');
        }

        final openCodeMessage = OpenCodeMessage.fromApiResponse(messageData);
        return openCodeMessage;
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> abortSession(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/abort');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Success - no logging needed
      } else {
        throw Exception('Failed to abort session: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<void> deleteSession(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId');
      final response = await _client.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Success - no logging needed
      } else {
        throw Exception('Failed to delete session: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Respond to a permission request (v1.1.1+)
  ///
  /// [requestId] - The permission request ID
  /// [response] - The user's response (once/always/reject)
  Future<void> respondToPermission(
    String requestId,
    PermissionResponse response,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/permission/$requestId/reply');

      final requestBody = json.encode({
        'reply': response.value,
      });

      final httpResponse = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 5));

      if (httpResponse.statusCode != 200 && httpResponse.statusCode != 204) {
        throw Exception('Failed to respond to permission: ${httpResponse.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get session status
  ///
  /// Returns the current status of the session (idle/busy/retry)
  Future<SessionStatus> getSessionStatus(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/status');

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return SessionStatus.fromJson(data);
      } else {
        throw Exception('Failed to get session status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateSessionSummary(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/summarize');

      final requestBody = json.encode({
        'providerID': _providerID,
        'modelID': _modelID,
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          
          // The server returns 'true' to indicate summary was initiated via SSE
          // Since we can't easily capture the SSE stream here, use a fallback
          if (responseData == true || 
              (responseData is Map && responseData.containsKey('success'))) {
            return 'Session ${sessionId.substring(0, 8)}...';
          }
          
          // Try different possible response formats
          String summary;
          if (responseData is String) {
            summary = responseData;
          } else if (responseData is Map) {
            summary = responseData['summary'] ?? 
                     responseData['description'] ?? 
                     responseData['text'] ?? 
                     responseData['content'] ?? 
                     responseData['message'] ?? 
                     'No summary available';
          } else {
            // Don't convert boolean true to string "true"
            summary = 'Session ${sessionId.substring(0, 8)}...';
          }
          
          return summary;
        } catch (e) {
          return 'Session ${sessionId.substring(0, 8)}...';
        }
      } else {
        // Only log errors, not the common cases
        if (response.statusCode == 404) {
          return 'Session ${sessionId.substring(0, 8)}...';
        } else if (response.statusCode == 405) {
          return await _tryGetSummary(sessionId);
        } else if (response.statusCode == 400) {
          return await _tryAlternativeSummaryFormats(sessionId);
        }
        
        throw Exception('Failed to generate summary: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _tryGetSummary(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/summary');
      final response = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['summary'] ?? responseData.toString();
      }
    } catch (e) {
      // Silent failure, fallback to default
    }
    
    return 'Session ${sessionId.substring(0, 8)}...';
  }

  Future<String> _tryAlternativeSummaryFormats(String sessionId) async {
    // Try different request body formats
    final alternatives = [
      {
        'providerID': _providerID,
        'modelID': _modelID,
        'sessionId': sessionId,
      },
      {
        'providerID': _providerID,
        'modelID': _modelID,
        'session_id': sessionId,
      },
      {
        'providerID': _providerID,
        'modelID': _modelID,
      },
    ];

    for (final body in alternatives) {
      try {
        final uri = Uri.parse('$_baseUrl/session/$sessionId/summarize');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          return responseData['summary'] ?? responseData.toString();
        }
      } catch (e) {
        // Silent failure, try next alternative
        continue;
      }
    }
    
    return 'Session ${sessionId.substring(0, 8)}...';
  }

  Future<List<OpenCodeMessage>> getSessionMessages(String sessionId, {int limit = 100}) async {
    try {
      final uri = Uri.parse('$_baseUrl/session/$sessionId/message?limit=$limit');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final messages = data.map((json) => OpenCodeMessage.fromApiResponse(json)).toList();
        return messages;
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ProvidersResponse> getAvailableProviders() async {
    try {
      final uri = Uri.parse('$_baseUrl/config/providers');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final providersResponse = ProvidersResponse.fromJson(data);
        return providersResponse;
      } else {
        throw Exception('Failed to get providers: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  void setProvider(String providerID, String modelID) {
    _providerID = providerID;
    _modelID = modelID;
  }

  Future<List<String>> fetchAndStoreAgents() async {
    _availableAgents = await getAgents();
    return _availableAgents;
  }

  Future<List<String>> getAgents() async {
    try {
      final uri = Uri.parse('$_baseUrl/agents');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((agent) {
          if (agent is String) return agent;
          if (agent is Map) return agent['id']?.toString() ?? agent['name']?.toString() ?? '';
          return '';
        }).where((name) => name.isNotEmpty).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}

