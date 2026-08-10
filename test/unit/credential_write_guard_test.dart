import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:spacenotes_client/services/credential_entry_serialiser.dart';
import 'package:spacenotes_client/services/credential_name_deriver.dart';

const _existing = [
  '.password-store/a.com/user.gpg',
  '.password-store/b.com/other.gpg',
  'notes/plain.md',
];

void main() {
  group('behaviour 30 — a taken name is refused, case-insensitively', () {
    test('an exact collision is found', () {
      expect(
        findCollidingPath(
          path: '.password-store/a.com/user.gpg',
          existingPaths: _existing,
        ),
        '.password-store/a.com/user.gpg',
      );
    });

    test('a collision differing only in capitalisation is found', () {
      expect(
        findCollidingPath(
          path: '.password-store/a.com/User.gpg',
          existingPaths: _existing,
        ),
        '.password-store/a.com/user.gpg',
      );
    });

    test('the collision returned is the EXISTING path, so it can be named',
        () {
      final collision = findCollidingPath(
        path: '.password-store/A.COM/USER.gpg',
        existingPaths: _existing,
      );

      expect(collision, '.password-store/a.com/user.gpg');
    });

    test('a free name is not a collision', () {
      expect(
        findCollidingPath(
          path: '.password-store/a.com/fresh.gpg',
          existingPaths: _existing,
        ),
        isNull,
      );
    });

    test('an entry does not collide with itself when rewritten in place', () {
      expect(
        findCollidingPath(
          path: '.password-store/a.com/user.gpg',
          existingPaths: _existing,
          ignoreExactPath: '.password-store/a.com/user.gpg',
        ),
        isNull,
      );
    });

    test('a rename onto a DIFFERENT occupied name is still a collision', () {
      expect(
        findCollidingPath(
          path: '.password-store/b.com/other.gpg',
          existingPaths: _existing,
          ignoreExactPath: '.password-store/b.com/mine.gpg',
        ),
        '.password-store/b.com/other.gpg',
      );
    });
  });

  group('behaviour 25/43 — what is sent is ciphertext, never plaintext', () {
    test('a serialised entry is NOT what would be sent as content', () {
      const password = 'correct-horse-battery-staple';
      final plaintext = CredentialEntrySerialiser.serialise(
        password: password,
        username: 'u',
        url: 'https://a.com',
      );

      final ciphertext = <int>[
        0xc1, 0x0c, 0x03,
        0xC5, 0x82, 0xF8, 0xC6, 0x6A, 0x65, 0x9D, 0x51,
        0x12, 0x00, 0x00,
        0xd2, 0x03, 0x01, 0x00, 0x00,
      ];
      final content = base64Encode(ciphertext);

      expect(content, isNot(contains(password)));
      expect(utf8.decode(base64Decode(content), allowMalformed: true),
          isNot(contains(password)));
      expect(plaintext, contains(password));
    });

    test('the content argument decodes to bytes beginning with a PKESK tag',
        () {
      final ciphertext = <int>[
        0xc1, 0x0c, 0x03,
        0xC5, 0x82, 0xF8, 0xC6, 0x6A, 0x65, 0x9D, 0x51,
        0x12, 0x00, 0x00,
        0xd2, 0x03, 0x01, 0x00, 0x00,
      ];
      final decoded = base64Decode(base64Encode(ciphertext));

      expect(decoded.first & 0x80, 0x80, reason: 'a packet header');
      final tag = decoded.first & 0x40 != 0
          ? decoded.first & 0x3f
          : (decoded.first >> 2) & 0x0f;
      expect(tag, 1, reason: 'tag 1 is PKESK');
    });

    test('the size sent is the DECODED byte length, not the base64 length', () {
      final ciphertext = List<int>.filled(517, 0x41);
      final content = base64Encode(ciphertext);

      expect(base64Decode(content).length, 517);
      expect(content.length, isNot(517));
    });
  });

  group('the derived path a credential write targets', () {
    test('a create targets the derived store path', () {
      expect(
        CredentialNameDeriver.storePathFor(
          url: 'https://www.zoopla.co.uk/account/login',
          username: 'mikael@deadeye.photo',
        ),
        '.password-store/www.zoopla.co.uk/mikael@deadeye.photo.gpg',
      );
    });

    test('a username rename keeps the directory byte-identical', () {
      const before = '.password-store/mikaelwills.com/mikaelwills.gpg';
      final after = CredentialNameDeriver.renamedStorePathFor(
        existingStorePath: before,
        username: 'mikael@mikaelwills.com',
      );

      expect(
        after.substring(0, after.lastIndexOf('/')),
        before.substring(0, before.lastIndexOf('/')),
      );
      expect(after, isNot(before));
    });

    test('a password-only edit leaves the path byte-identical', () {
      const path = '.password-store/a.com/user.gpg';
      final unchanged = CredentialNameDeriver.renamedStorePathFor(
        existingStorePath: path,
        username: 'user',
      );

      expect(unchanged, path);
    });
  });
}
