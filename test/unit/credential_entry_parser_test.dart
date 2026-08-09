import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/credential_entry_parser.dart';

void main() {
  test('password is the first line', () {
    final c = DecryptedCredential.parse('hunter2\nusername: mikael\n');
    expect(c.password, 'hunter2');
    expect(c.username, 'mikael');
  });

  test('metadata keys are case-insensitive', () {
    final c = DecryptedCredential.parse('pw\nUsername: a\nURL: https://x.com');
    expect(c.username, 'a');
    expect(c.url, 'https://x.com');
  });

  test('a password-only entry has no fields', () {
    final c = DecryptedCredential.parse('justapassword');
    expect(c.password, 'justapassword');
    expect(c.username, isNull);
    expect(c.url, isNull);
  });

  test('a colon in a value survives', () {
    final c = DecryptedCredential.parse('pw\nurl: https://x.com:8443/a');
    expect(c.url, 'https://x.com:8443/a');
  });
}
