import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/screens/credential_screen.dart';

void main() {
  test('parses site and account from a store path', () {
    final e = CredentialEntry.fromPath(
        '.password-store/www.zoopla.co.uk/mikael@deadeye.photo.gpg');
    expect(e.site, 'www.zoopla.co.uk');
    expect(e.account, 'mikael@deadeye.photo');
  });

  test('keeps nested site directories intact', () {
    final e = CredentialEntry.fromPath('.password-store/a/b/user.gpg');
    expect(e.site, 'a/b');
    expect(e.account, 'user');
  });

  test('an entry at the store root has no site', () {
    final e = CredentialEntry.fromPath('.password-store/loose.gpg');
    expect(e.site, '');
    expect(e.account, 'loose');
  });
}
