import 'package:flutter/services.dart';

class PgpDecryptException implements Exception {
  const PgpDecryptException(this.message);

  final String message;

  @override
  String toString() => 'PgpDecryptException: $message';
}

class PgpEncryptException implements Exception {
  const PgpEncryptException(this.message);

  final String message;

  @override
  String toString() => 'PgpEncryptException: $message';
}

class SpaceNotesPgp {
  static const _channel = MethodChannel('spacenotes/pgp');

  static Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List publicKeys,
    required Uint8List gpgId,
  }) async {
    try {
      final ciphertext = await _channel.invokeMethod<Uint8List>('encrypt', {
        'plaintext': plaintext,
        'publicKeys': publicKeys,
        'gpgId': gpgId,
      });
      if (ciphertext == null || ciphertext.isEmpty) {
        throw const PgpEncryptException('no ciphertext returned');
      }
      return ciphertext;
    } on PlatformException catch (e) {
      throw PgpEncryptException(e.message ?? e.code);
    } on MissingPluginException {
      throw const PgpEncryptException(
        'encryption is not available on this platform',
      );
    }
  }

  /// Decrypts an OpenPGP message with [privateKey].
  ///
  /// Both arguments are raw bytes. The key may be armored or binary.
  /// Throws [PgpDecryptException] when the key cannot read the message.
  static Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List privateKey,
  }) async {
    try {
      final plaintext = await _channel.invokeMethod<Uint8List>('decrypt', {
        'ciphertext': ciphertext,
        'privateKey': privateKey,
      });
      if (plaintext == null) {
        throw const PgpDecryptException('no plaintext returned');
      }
      return plaintext;
    } on PlatformException catch (e) {
      throw PgpDecryptException(e.message ?? e.code);
    } on MissingPluginException {
      throw const PgpDecryptException(
        'decryption is not available on this platform',
      );
    }
  }
}
