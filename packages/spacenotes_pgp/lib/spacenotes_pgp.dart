import 'package:flutter/services.dart';

class PgpDecryptException implements Exception {
  const PgpDecryptException(this.message);

  final String message;

  @override
  String toString() => 'PgpDecryptException: $message';
}

class SpaceNotesPgp {
  static const _channel = MethodChannel('spacenotes/pgp');

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
