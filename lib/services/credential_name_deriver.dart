class CredentialNameException implements Exception {
  const CredentialNameException(this.message);

  final String message;

  @override
  String toString() => 'CredentialNameException: $message';
}

class CredentialNameDeriver {
  static const storeRoot = '.password-store';

  static String siteFor(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const CredentialNameException('a URL is required');
    }

    final withScheme =
        trimmed.contains('://') ? trimmed : 'https://$trimmed';

    final Uri parsed;
    try {
      parsed = Uri.parse(withScheme);
    } on FormatException catch (e) {
      throw CredentialNameException('cannot read the URL: $e');
    }

    final host = parsed.host.toLowerCase();
    if (host.isEmpty) {
      throw CredentialNameException('the URL names no host: $url');
    }

    if (!parsed.hasPort) {
      return host;
    }
    return '$host-${parsed.port}';
  }

  static String accountFor(String username) {
    final account = username.trim();
    if (account.isEmpty) {
      throw const CredentialNameException('a username is required');
    }
    if (account.contains('/')) {
      throw CredentialNameException(
        'a username cannot contain a slash: $username',
      );
    }
    return account;
  }

  static String relativePathFor({
    required String url,
    required String username,
  }) =>
      '${siteFor(url)}/${accountFor(username)}.gpg';

  static String storePathFor({
    required String url,
    required String username,
  }) =>
      '$storeRoot/${relativePathFor(url: url, username: username)}';

  static String renamedStorePathFor({
    required String existingStorePath,
    required String username,
  }) {
    final separator = existingStorePath.lastIndexOf('/');
    if (separator <= 0) {
      throw CredentialNameException(
        'a credential path always has a site directory: $existingStorePath',
      );
    }
    final directory = existingStorePath.substring(0, separator);
    return '$directory/${accountFor(username)}.gpg';
  }
}
