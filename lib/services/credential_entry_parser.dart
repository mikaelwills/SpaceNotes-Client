/// A decrypted credential: the password on the first line, then metadata
/// lines such as `username:` and `url:`.
class DecryptedCredential {
  const DecryptedCredential({
    required this.password,
    required this.fields,
  });

  final String password;
  final Map<String, String> fields;

  String? get username => fields['username'] ?? fields['user'] ?? fields['login'];

  String? get url => fields['url'] ?? fields['uri'];

  static DecryptedCredential parse(String plaintext) {
    final lines = plaintext.split('\n');
    final password = lines.isEmpty ? '' : lines.first.trim();

    final fields = <String, String>{};
    for (final line in lines.skip(1)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim().toLowerCase();
      final value = line.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      fields.putIfAbsent(key, () => value);
    }

    return DecryptedCredential(password: password, fields: fields);
  }
}
