import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/credential_writer.dart';

const _storeGpgId = 'C582F8C66A659D51!\n'
    '633FB31FF42971F1!\n'
    '4CC2B0682D695565!\n'
    '29F11110A0624877!\n';

String? _realPublicKeys() {
  final home = Platform.environment['HOME'];
  if (home == null) return null;
  final file = File('$home/.password-store/.gpg-pubkeys.asc');
  if (!file.existsSync()) return null;
  return file.readAsStringSync();
}

class _Recorder {
  final List<Map<String, String?>> calls = [];

  Future<void> upsert({
    required String id,
    required String path,
    required String content,
    String? replacingPath,
  }) async {
    calls.add({
      'id': id,
      'path': path,
      'content': content,
      'replacingPath': replacingPath,
    });
  }
}

Uint8List _fakeCiphertextFor(Uint8List plaintext) =>
    Uint8List.fromList([0xc1, 0x0c, 0x03, ...plaintext]);

CredentialWriter _writer({
  required _Recorder recorder,
  CredentialEncrypt? encrypt,
  CredentialDecrypt? decrypt,
  CredentialPrivateKeyRead? readPrivateKey,
  String? publicKeys,
  String? gpgId,
}) {
  return CredentialWriter(
    gpgId: gpgId ?? _storeGpgId,
    publicKeysArmored: publicKeys ?? _realPublicKeys()!,
    encrypt: encrypt ??
        ({
          required Uint8List plaintext,
          required Uint8List publicKeys,
          required Uint8List gpgId,
        }) async =>
            _fakeCiphertextFor(plaintext),
    decrypt: decrypt ??
        ({
          required Uint8List ciphertext,
          required Uint8List privateKey,
        }) async =>
            Uint8List.sublistView(ciphertext, 3),
    readPrivateKey:
        readPrivateKey ?? () async => Uint8List.fromList([1, 2, 3]),
    upsert: recorder.upsert,
  );
}

void main() {
  group('behaviour 26 — all three fields are required', () {
    for (final missing in ['password', 'username', 'url']) {
      test('a create with an empty $missing is refused with no write', () async {
        if (_realPublicKeys() == null) return;
        final recorder = _Recorder();

        await expectLater(
          _writer(recorder: recorder).write(
            CredentialWriteRequest(
              id: 'id-1',
              password: missing == 'password' ? '  ' : 'p',
              username: missing == 'username' ? '  ' : 'u',
              url: missing == 'url' ? '  ' : 'https://a.com',
            ),
          ),
          throwsA(isA<CredentialWriteFailure>()),
        );
        expect(recorder.calls, isEmpty);
      });
    }
  });

  group('behaviour 32/38 — one call carrying both path and content', () {
    test('a username edit is exactly ONE upsert with the new path and content',
        () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 's3cr3t',
          username: 'mikael@mikaelwills.com',
          url: 'https://mikaelwills.com',
          existingStorePath:
              '.password-store/mikaelwills.com/mikaelwills.gpg',
        ),
      );

      expect(recorder.calls, hasLength(1));
      final call = recorder.calls.single;
      expect(
        call['path'],
        '.password-store/mikaelwills.com/mikael@mikaelwills.com.gpg',
      );
      expect(call['content'], isNotEmpty);
      expect(
        call['replacingPath'],
        '.password-store/mikaelwills.com/mikaelwills.gpg',
      );
    });

    test('the new path keeps the site directory unchanged', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'p',
          username: 'renamed',
          url: 'https://a.com',
          existingStorePath: '.password-store/a.com/original.gpg',
        ),
      );

      expect(recorder.calls.single['path'], '.password-store/a.com/renamed.gpg');
    });
  });

  group('behaviour 31 — a password-only edit leaves the path identical', () {
    test('the path argument is byte-identical to the existing path', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();
      const existing = '.password-store/a.com/user.gpg';

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'brand-new-password',
          username: 'user',
          url: 'https://a.com',
          existingStorePath: existing,
        ),
      );

      expect(recorder.calls.single['path'], existing);
    });
  });

  group('behaviour 25/43 — only ciphertext leaves the device', () {
    test('the content sent contains no trace of the password', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();
      const password = 'correct-horse-battery-staple';

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: password,
          username: 'u',
          url: 'https://a.com',
        ),
      );

      final content = recorder.calls.single['content']!;
      expect(content, isNot(contains(password)));
      final decoded = base64Decode(content);
      expect(decoded.first & 0x80, 0x80);
      expect(decoded.first & 0x3f, 1, reason: 'first packet is a PKESK');
    });
  });

  group('behaviour 37 — round-trip preflight before anything is sent', () {
    test('a preflight returning different bytes abandons the write', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await expectLater(
        _writer(
          recorder: recorder,
          decrypt: ({
            required Uint8List ciphertext,
            required Uint8List privateKey,
          }) async =>
              Uint8List.fromList(utf8.encode('something else entirely\n')),
        ).write(
          const CredentialWriteRequest(
            id: 'id-1',
            password: 'p',
            username: 'u',
            url: 'https://a.com',
          ),
        ),
        throwsA(isA<CredentialWriteFailure>()),
      );
      expect(recorder.calls, isEmpty, reason: 'zero reducer calls');
    });

    test('a preflight that throws abandons the write', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await expectLater(
        _writer(
          recorder: recorder,
          decrypt: ({
            required Uint8List ciphertext,
            required Uint8List privateKey,
          }) async =>
              throw Exception('key cannot read it'),
        ).write(
          const CredentialWriteRequest(
            id: 'id-1',
            password: 'p',
            username: 'u',
            url: 'https://a.com',
          ),
        ),
        throwsA(isA<CredentialWriteFailure>()),
      );
      expect(recorder.calls, isEmpty);
    });

    test('a keyless device refuses to write rather than sending unverified',
        () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await expectLater(
        _writer(recorder: recorder, readPrivateKey: () async => null).write(
          const CredentialWriteRequest(
            id: 'id-1',
            password: 'p',
            username: 'u',
            url: 'https://a.com',
          ),
        ),
        throwsA(
          isA<CredentialWriteFailure>().having(
            (e) => e.message,
            'message',
            contains('holds no key'),
          ),
        ),
      );
      expect(recorder.calls, isEmpty);
    });

    test('the preflight runs BEFORE the upsert, not after', () async {
      if (_realPublicKeys() == null) return;
      final order = <String>[];
      final recorder = _Recorder();

      final writer = CredentialWriter(
        gpgId: _storeGpgId,
        publicKeysArmored: _realPublicKeys()!,
        encrypt: ({
          required Uint8List plaintext,
          required Uint8List publicKeys,
          required Uint8List gpgId,
        }) async {
          order.add('encrypt');
          return _fakeCiphertextFor(plaintext);
        },
        decrypt: ({
          required Uint8List ciphertext,
          required Uint8List privateKey,
        }) async {
          order.add('decrypt');
          return Uint8List.sublistView(ciphertext, 3);
        },
        readPrivateKey: () async => Uint8List.fromList([1]),
        upsert: ({
          required String id,
          required String path,
          required String content,
          String? replacingPath,
        }) async {
          order.add('upsert');
          await recorder.upsert(
            id: id,
            path: path,
            content: content,
            replacingPath: replacingPath,
          );
        },
      );

      await writer.write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'p',
          username: 'u',
          url: 'https://a.com',
        ),
      );

      expect(order, ['encrypt', 'decrypt', 'upsert']);
    });
  });

  group('behaviour 36 — a missing recipient refuses, nothing is sent', () {
    test('the recipient list reaches the encrypt boundary verbatim', () async {
      final publicKeys = _realPublicKeys();
      if (publicKeys == null) return;
      final recorder = _Recorder();
      const gpgId = '$_storeGpgId\nDEADBEEFDEADBEEF!\n';
      Uint8List? seenGpgId;
      Uint8List? seenPublicKeys;

      await _writer(
        recorder: recorder,
        gpgId: gpgId,
        publicKeys: publicKeys,
        encrypt: ({
          required Uint8List plaintext,
          required Uint8List publicKeys,
          required Uint8List gpgId,
        }) async {
          seenGpgId = gpgId;
          seenPublicKeys = publicKeys;
          return _fakeCiphertextFor(plaintext);
        },
      ).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'p',
          username: 'u',
          url: 'https://a.com',
        ),
      );

      expect(utf8.decode(seenGpgId!), gpgId);
      expect(utf8.decode(seenPublicKeys!), publicKeys);
    });

    test('a refusal at the encrypt boundary sends nothing', () async {
      final recorder = _Recorder();

      await expectLater(
        _writer(
          recorder: recorder,
          encrypt: ({
            required Uint8List plaintext,
            required Uint8List publicKeys,
            required Uint8List gpgId,
          }) async =>
              throw Exception(
                'pgpmobile: refusing to encrypt, no public key for 1 of 5 '
                '.gpg-id recipients: DEADBEEFDEADBEEF',
              ),
        ).write(
          const CredentialWriteRequest(
            id: 'id-1',
            password: 'p',
            username: 'u',
            url: 'https://a.com',
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(recorder.calls, isEmpty);
    });
  });

  group('behaviour 27/27a — the create path is derived', () {
    test('a create targets the derived store path', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'p',
          username: 'mikael@deadeye.photo',
          url: 'https://www.zoopla.co.uk/account/login',
        ),
      );

      expect(
        recorder.calls.single['path'],
        '.password-store/www.zoopla.co.uk/mikael@deadeye.photo.gpg',
      );
      expect(recorder.calls.single['replacingPath'], isNull);
    });

    test('a create at a host:port lands in the -<port> directory', () async {
      if (_realPublicKeys() == null) return;
      final recorder = _Recorder();

      await _writer(recorder: recorder).write(
        const CredentialWriteRequest(
          id: 'id-1',
          password: 'p',
          username: 'mikael',
          url: 'https://10.10.10.40:9000',
        ),
      );

      expect(
        recorder.calls.single['path'],
        '.password-store/10.10.10.40-9000/mikael.gpg',
      );
    });

  });
}
