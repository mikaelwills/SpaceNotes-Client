import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/credential_entry_parser.dart';
import 'package:spacenotes_client/services/credential_entry_serialiser.dart';

void main() {
  group('behaviour 3 — password on line 1, then metadata', () {
    test('the exact bytes, including the trailing newline', () {
      final serialised = CredentialEntrySerialiser.serialise(
        password: 's3cr3t',
        username: 'mikael@deadeye.photo',
        url: 'https://www.zoopla.co.uk/account/login',
      );

      expect(
        serialised,
        's3cr3t\n'
        'username: mikael@deadeye.photo\n'
        'url: https://www.zoopla.co.uk/account/login\n',
      );
      expect(serialised.endsWith('\n'), isTrue);
    });

    test('the emitted keys are literally username and url, not synonyms', () {
      final lines = CredentialEntrySerialiser.serialise(
        password: 'p',
        username: 'u',
        url: 'https://a.com',
      ).split('\n');

      expect(lines[1], startsWith('username: '));
      expect(lines[2], startsWith('url: '));
      expect(lines[1], isNot(startsWith('login:')));
      expect(lines[1], isNot(startsWith('user:')));
      expect(lines[2], isNot(startsWith('uri:')));
    });

    test('line 1 is the password alone, with no label or leading whitespace',
        () {
      final first = CredentialEntrySerialiser.serialise(
        password: 's3cr3t',
        username: 'u',
        url: 'https://a.com',
      ).split('\n').first;

      expect(first, 's3cr3t');
    });
  });

  group('round trip through the real parser', () {
    test('parse(serialise(x)) equals x in all three fields', () {
      const password = 's3cr3t';
      const username = 'mikael@deadeye.photo';
      const url = 'https://www.zoopla.co.uk/account/login';

      final parsed = DecryptedCredential.parse(
        CredentialEntrySerialiser.serialise(
          password: password,
          username: username,
          url: url,
        ),
      );

      expect(parsed.password, password);
      expect(parsed.username, username);
      expect(parsed.url, url);
    });

    test('a password containing spaces survives the round trip', () {
      const password = 'correct horse battery staple';

      final parsed = DecryptedCredential.parse(
        CredentialEntrySerialiser.serialise(
          password: password,
          username: 'u',
          url: 'https://a.com',
        ),
      );

      expect(parsed.password, password);
    });

    test('a URL with a port survives the round trip verbatim', () {
      const url = 'https://10.10.10.40:9000';

      final parsed = DecryptedCredential.parse(
        CredentialEntrySerialiser.serialise(
          password: 'p',
          username: 'u',
          url: url,
        ),
      );

      expect(parsed.url, url);
    });
  });

  test('an empty password is refused', () {
    expect(
      () => CredentialEntrySerialiser.serialise(
        password: '',
        username: 'u',
        url: 'https://a.com',
      ),
      throwsArgumentError,
    );
  });
}
