import 'package:web/web.dart' as web;

class WebHostnameService {
  static String? getCurrentHostname() {
    final hostname = web.window.location.hostname;
    if (hostname.isNotEmpty && hostname != 'localhost' && hostname != '127.0.0.1') {
      return hostname;
    }
    return null;
  }
}
