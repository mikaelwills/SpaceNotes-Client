import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    test('defaults to 24 characters', () {
      expect(PasswordGenerator.generate().length, 24);
    });

    test('honours a requested length', () {
      expect(PasswordGenerator.generate(length: 40).length, 40);
    });

    test('rejects lengths below the four required classes', () {
      expect(() => PasswordGenerator.generate(length: 3), throwsArgumentError);
    });

    test('always contains all four character classes', () {
      final lower = RegExp('[a-z]');
      final upper = RegExp('[A-Z]');
      final digit = RegExp('[0-9]');
      final symbol = RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,.?]');
      for (var i = 0; i < 500; i++) {
        final pw = PasswordGenerator.generate();
        expect(lower.hasMatch(pw), isTrue, reason: pw);
        expect(upper.hasMatch(pw), isTrue, reason: pw);
        expect(digit.hasMatch(pw), isTrue, reason: pw);
        expect(symbol.hasMatch(pw), isTrue, reason: pw);
      }
    });

    test('does not repeat across calls', () {
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.add(PasswordGenerator.generate());
      }
      expect(seen.length, 500);
    });
  });
}
