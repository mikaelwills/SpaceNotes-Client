import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import '../repositories/spacetimedb_notes_repository.dart';

class WebConfigService {
  static Future<void> tryAutoConfigureFromServer(SpacetimeDbNotesRepository repo) async {
    try {
      final currentHost = web.window.location.hostname;
      final response = await http.get(Uri.parse('/config.json')).timeout(
        const Duration(seconds: 2),
      );

      if (response.statusCode == 200) {
        final config = jsonDecode(response.body) as Map<String, dynamic>;
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
}
