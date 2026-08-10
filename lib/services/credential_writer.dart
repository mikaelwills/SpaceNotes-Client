import 'dart:convert';
import 'dart:typed_data';

import 'credential_entry_parser.dart';
import 'credential_entry_serialiser.dart';
import 'credential_name_deriver.dart';

typedef CredentialEncrypt = Future<Uint8List> Function({
  required Uint8List plaintext,
  required Uint8List publicKeys,
  required Uint8List gpgId,
});

typedef CredentialDecrypt = Future<Uint8List> Function({
  required Uint8List ciphertext,
  required Uint8List privateKey,
});

typedef CredentialPrivateKeyRead = Future<Uint8List?> Function();

typedef CredentialUpsert = Future<void> Function({
  required String id,
  required String path,
  required String content,
  String? replacingPath,
});

class CredentialWriteFailure implements Exception {
  const CredentialWriteFailure(this.message);

  final String message;

  @override
  String toString() => 'CredentialWriteFailure: $message';
}

class CredentialWriteRequest {
  const CredentialWriteRequest({
    required this.id,
    required this.password,
    required this.username,
    required this.url,
    this.existingStorePath,
  });

  final String id;
  final String password;
  final String username;
  final String url;
  final String? existingStorePath;
}

class CredentialWriter {
  const CredentialWriter({
    required this.gpgId,
    required this.publicKeysArmored,
    required this.encrypt,
    required this.decrypt,
    required this.readPrivateKey,
    required this.upsert,
  });

  final String gpgId;
  final String publicKeysArmored;
  final CredentialEncrypt encrypt;
  final CredentialDecrypt decrypt;
  final CredentialPrivateKeyRead readPrivateKey;
  final CredentialUpsert upsert;

  String targetPathFor(CredentialWriteRequest request) {
    final existing = request.existingStorePath;
    if (existing == null) {
      return CredentialNameDeriver.storePathFor(
        url: request.url,
        username: request.username,
      );
    }
    return CredentialNameDeriver.renamedStorePathFor(
      existingStorePath: existing,
      username: request.username,
    );
  }

  Future<void> write(CredentialWriteRequest request) async {
    if (request.password.trim().isEmpty) {
      throw const CredentialWriteFailure('a password is required');
    }
    if (request.username.trim().isEmpty) {
      throw const CredentialWriteFailure('a username is required');
    }
    if (request.url.trim().isEmpty) {
      throw const CredentialWriteFailure('a URL is required');
    }

    final targetPath = targetPathFor(request);

    final privateKey = await readPrivateKey();
    if (privateKey == null) {
      throw const CredentialWriteFailure(
        'this device holds no key, so it cannot confirm it could read back '
        'what it just encrypted; nothing was written',
      );
    }

    final plaintext = CredentialEntrySerialiser.serialise(
      password: request.password,
      username: request.username,
      url: request.url,
    );
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final ciphertext = await encrypt(
      plaintext: plaintextBytes,
      publicKeys: Uint8List.fromList(utf8.encode(publicKeysArmored)),
      gpgId: Uint8List.fromList(utf8.encode(gpgId)),
    );
    if (ciphertext.isEmpty) {
      throw const CredentialWriteFailure(
        'encryption produced no ciphertext, so nothing was written',
      );
    }

    await _preflight(
      ciphertext: ciphertext,
      expected: plaintext,
      privateKey: privateKey,
    );

    await upsert(
      id: request.id,
      path: targetPath,
      content: base64Encode(ciphertext),
      replacingPath: request.existingStorePath,
    );
  }

  Future<void> _preflight({
    required Uint8List ciphertext,
    required String expected,
    required Uint8List privateKey,
  }) async {
    final Uint8List readBack;
    try {
      readBack = await decrypt(ciphertext: ciphertext, privateKey: privateKey);
    } on Exception catch (e) {
      throw CredentialWriteFailure(
        'the entry did not survive its own round trip, so nothing was '
        'written: $e',
      );
    }

    final decoded = utf8.decode(readBack, allowMalformed: true);
    if (decoded != expected) {
      throw const CredentialWriteFailure(
        'the entry did not survive its own round trip, so nothing was written',
      );
    }

    final reparsed = DecryptedCredential.parse(decoded);
    final source = DecryptedCredential.parse(expected);
    if (reparsed.password != source.password ||
        reparsed.username != source.username ||
        reparsed.url != source.url) {
      throw const CredentialWriteFailure(
        'the round trip did not reproduce every field, so nothing was written',
      );
    }
  }
}
