import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import '../repositories/spacetimedb_notes_repository.dart';
import '../blocs/config/config_cubit.dart';

class WebConfigService {
  static Map<String, dynamic>? _cachedConfig;

  static Future<Map<String, dynamic>?> _fetchConfig() async {
    if (_cachedConfig != null) return _cachedConfig;

    try {
      final response = await http.get(Uri.parse('/config.json')).timeout(
        const Duration(seconds: 2),
      );
      if (response.statusCode == 200) {
        _cachedConfig = jsonDecode(response.body) as Map<String, dynamic>;
        return _cachedConfig;
      }
    } catch (e) {
      print('Could not fetch config.json: $e');
    }
    return null;
  }

  static Future<void> tryAutoConfigureFromServer(SpacetimeDbNotesRepository repo) async {
    try {
      final currentHost = web.window.location.hostname;
      final config = await _fetchConfig();

      if (config != null) {
        final port = config['spacetimedb_port'] as int?;

        if (port != null && currentHost.isNotEmpty) {
          final host = '$currentHost:$port';
          print('Auto-configured SpacetimeDB host from server: $host');
          await repo.configure(host: host);
          await repo.connectAndGetInitialData();
          print('Auto-connected to SpacetimeDB');
        }
      }
    } catch (e) {
      print('Could not fetch config.json (standalone mode): $e');
    }
  }

  static Future<void> tryAutoConfigureOpenCode(ConfigCubit configCubit) async {
    try {
      final currentHost = web.window.location.hostname;
      final config = await _fetchConfig();

      if (config != null) {
        final port = config['opencode_port'] as int?;

        if (port != null && currentHost.isNotEmpty) {
          print('Auto-configured OpenCode from server: $currentHost:$port');
          await configCubit.updateServer(currentHost, port: port);
        }
      }
    } catch (e) {
      print('Could not auto-configure OpenCode: $e');
    }
  }
}
