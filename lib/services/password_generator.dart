import 'dart:math';

/// Generates cryptographically secure passwords using [Random.secure].
class PasswordGenerator {
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+[]{};:,.?';

  static const _defaultLength = 24;

  /// Returns a password of [length] characters drawn from all four classes,
  /// guaranteeing at least one of each. Throws if [length] is under 4.
  static String generate({int length = _defaultLength}) {
    if (length < 4) {
      throw ArgumentError.value(length, 'length', 'must be at least 4');
    }
    final rng = Random.secure();
    const classes = [_lower, _upper, _digits, _symbols];
    final all = classes.join();

    final chars = [
      for (final cls in classes) cls[rng.nextInt(cls.length)],
      for (var i = classes.length; i < length; i++)
        all[rng.nextInt(all.length)],
    ];

    for (var i = chars.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }
}
