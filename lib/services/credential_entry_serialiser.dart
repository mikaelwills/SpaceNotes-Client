class CredentialEntrySerialiser {
  static const usernameKey = 'username';
  static const urlKey = 'url';

  static String serialise({
    required String password,
    required String username,
    required String url,
  }) {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }

    final lines = <String>[password];
    if (username.isNotEmpty) {
      lines.add('$usernameKey: $username');
    }
    if (url.isNotEmpty) {
      lines.add('$urlKey: $url');
    }
    return '${lines.join('\n')}\n';
  }
}
