import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The macOS plugin's Swift side reads `useDataProtectionKeyChain` while
/// `MacOsOptions.toMap` emits `usesDataProtectionKeychain`; the casing mismatch
/// means the Dart value never reaches native and the default (true) always
/// wins. Emitting both spellings makes the value take effect.
class _FixedMacOsOptions extends MacOsOptions {
  _FixedMacOsOptions({
    super.accessibility,
    super.accessControlFlags,
    super.groupId,
  });

  @override
  Map<String, String> toMap() => {
        ...super.toMap(),
        'useDataProtectionKeyChain': '$usesDataProtectionKeychain',
      };
}

/// Holds this device's OpenPGP private subkey in the platform keystore.
///
/// The key is released only after a local biometric check. It never leaves the
/// device: the accessibility class excludes it from backups and from migration
/// to a new device, so it cannot ride an iCloud restore.
class CredentialKeyStore {
  CredentialKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'credential_private_key';

  final FlutterSecureStorage _storage;

  /// Access control must be set explicitly. With an empty flag list the plugin
  /// falls back to a plain keychain item and there is NO biometric gate.
  ///
  /// `biometryCurrentSet` invalidates the key when biometric enrolment changes,
  /// so an attacker who knows the passcode cannot enrol their own finger and
  /// read it. On macOS `devicePasscode` is OR'd in because not every Mac has
  /// Touch ID.
  static List<AccessControlFlag> get _accessControl => Platform.isMacOS
      ? const [
          AccessControlFlag.biometryCurrentSet,
          AccessControlFlag.or,
          AccessControlFlag.devicePasscode,
        ]
      : const [AccessControlFlag.biometryCurrentSet];

  /// `passcode` is the only accessibility class excluded from backups, which
  /// is what keeps the key from riding an iCloud restore onto another device.
  /// Turning off the device passcode deletes every item stored under it.
  static const _accessibility = KeychainAccessibility.passcode;

  IOSOptions get _iosOptions => IOSOptions(
        accessibility: _accessibility,
        accessControlFlags: _accessControl,
      );

  MacOsOptions get _macOptions => _FixedMacOsOptions(
        accessibility: _accessibility,
        accessControlFlags: _accessControl,
        groupId: 'com.spacenotes.client',
      );

  Future<bool> hasKey() async => _storage.containsKey(
        key: _keyName,
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );

  /// Stores [privateKey], replacing any key already held.
  ///
  /// Replacing discards the previous key with no usable trace, which is the
  /// path used when a key is reissued after a compromise.
  Future<void> store(Uint8List privateKey) => _storage.write(
        key: _keyName,
        value: base64Encode(privateKey),
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );

  /// Reads the key, prompting for the device's biometric check.
  ///
  /// Returns null when no key is held or the check was refused.
  Future<Uint8List?> read() async {
    final stored = await _storage.read(
      key: _keyName,
      iOptions: _iosOptions,
      mOptions: _macOptions,
    );
    if (stored == null) return null;
    return base64Decode(stored);
  }

  Future<void> delete() => _storage.delete(
        key: _keyName,
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );
}
