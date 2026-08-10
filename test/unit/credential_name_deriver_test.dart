import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/credential_name_deriver.dart';

void main() {
  group('behaviour 27 — the name follows from what was supplied', () {
    test("the spec's own example", () {
      expect(
        CredentialNameDeriver.relativePathFor(
          url: 'https://www.zoopla.co.uk/account/login',
          username: 'mikael@deadeye.photo',
        ),
        'www.zoopla.co.uk/mikael@deadeye.photo.gpg',
      );
    });

    test('the subdomain is kept whole, not reduced to a registrable domain',
        () {
      expect(
        CredentialNameDeriver.siteFor('https://login.mysite.co.uk/x'),
        'login.mysite.co.uk',
      );
    });

    test('the host is lowercased', () {
      expect(
        CredentialNameDeriver.siteFor('https://WWW.Zoopla.CO.UK'),
        'www.zoopla.co.uk',
      );
    });

    test('the path, query and fragment are all discarded', () {
      expect(
        CredentialNameDeriver.siteFor('https://a.com/deep/path?q=1#frag'),
        'a.com',
      );
    });

    test('http and https give the same site', () {
      expect(
        CredentialNameDeriver.siteFor('http://a.com'),
        CredentialNameDeriver.siteFor('https://a.com'),
      );
    });

    test('the store path is rooted at .password-store', () {
      expect(
        CredentialNameDeriver.storePathFor(
          url: 'https://a.com',
          username: 'u',
        ),
        '.password-store/a.com/u.gpg',
      );
    });

    test('two accounts at one URL share a parent directory', () {
      final first = CredentialNameDeriver.storePathFor(
        url: 'https://a.com',
        username: 'one',
      );
      final second = CredentialNameDeriver.storePathFor(
        url: 'https://a.com',
        username: 'two',
      );
      expect(
        first.substring(0, first.lastIndexOf('/')),
        second.substring(0, second.lastIndexOf('/')),
      );
    });
  });

  group('behaviour 27a — a port is part of the site name, after a dash', () {
    test('a non-default port is kept as a -<port> suffix', () {
      expect(
        CredentialNameDeriver.relativePathFor(
          url: 'https://10.10.10.40:9000',
          username: 'mikael',
        ),
        '10.10.10.40-9000/mikael.gpg',
      );
    });

    test('two ports on one host derive two different, non-equal sites', () {
      final nineThousand =
          CredentialNameDeriver.siteFor('https://10.10.10.40:9000');
      final eightyEighty =
          CredentialNameDeriver.siteFor('https://10.10.10.40:8080');

      expect(nineThousand, '10.10.10.40-9000');
      expect(eightyEighty, '10.10.10.40-8080');
      expect(nineThousand, isNot(eightyEighty));
    });

    test('a default https port 443 is DROPPED, by decision', () {
      expect(CredentialNameDeriver.siteFor('https://a.com:443'), 'a.com');
    });

    test('a default http port 80 is DROPPED, by decision', () {
      expect(CredentialNameDeriver.siteFor('http://a.com:80'), 'a.com');
    });

    test('port 443 on http is KEPT, because it is not that scheme\'s default',
        () {
      expect(CredentialNameDeriver.siteFor('http://a.com:443'), 'a.com-443');
    });
  });

  group('rename derivation keeps the directory', () {
    test('a username change renames within the site directory', () {
      expect(
        CredentialNameDeriver.renamedStorePathFor(
          existingStorePath: '.password-store/mikaelwills.com/mikaelwills.gpg',
          username: 'mikael@mikaelwills.com',
        ),
        '.password-store/mikaelwills.com/mikael@mikaelwills.com.gpg',
      );
    });
  });

  group('refusals', () {
    test('an empty URL is refused', () {
      expect(
        () => CredentialNameDeriver.siteFor('  '),
        throwsA(isA<CredentialNameException>()),
      );
    });

    test('a URL with no host is refused', () {
      expect(
        () => CredentialNameDeriver.siteFor('https:///just/a/path'),
        throwsA(isA<CredentialNameException>()),
      );
    });

    test('an empty username is refused', () {
      expect(
        () => CredentialNameDeriver.accountFor('   '),
        throwsA(isA<CredentialNameException>()),
      );
    });

    test('a username containing a slash is refused', () {
      expect(
        () => CredentialNameDeriver.accountFor('a/b'),
        throwsA(isA<CredentialNameException>()),
      );
    });
  });
}
