import 'package:spacetimedb_sdk/spacetimedb_sdk.dart' as stdb;
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-based AuthTokenStore for persistent token storage
///
/// This implementation stores SpacetimeDB authentication tokens in
/// SharedPreferences, ensuring tokens persist across app restarts.
///
/// Features:
/// - Automatic token persistence
/// - Survives app restarts
/// - Maintains user identity across sessions
class SharedPreferencesTokenStore implements stdb.AuthTokenStore {
  static const String _tokenKey = 'spacetimedb_auth_token';

  @override
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  @override
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  @override
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
