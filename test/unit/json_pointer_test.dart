import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/json_pointer.dart';

void main() {
  group('JsonPointer.read', () {
    test('reads top-level key', () {
      final r = JsonPointer.read({'foo': 'bar'}, '/foo');
      expect(r, 'bar');
    });

    test('reads nested map', () {
      final r = JsonPointer.read({
        'a': {'b': 42}
      }, '/a/b');
      expect(r, 42);
    });

    test('reads list element', () {
      final r = JsonPointer.read({
        'items': ['x', 'y', 'z']
      }, '/items/1');
      expect(r, 'y');
    });

    test('reads through mixed map+list', () {
      final r = JsonPointer.read({
        'items': [
          {'name': 'a'},
          {'name': 'b'},
        ]
      }, '/items/1/name');
      expect(r, 'b');
    });

    test('returns null for missing path', () {
      expect(JsonPointer.read({'foo': 'bar'}, '/missing'), isNull);
    });

    test('returns null for out-of-range index', () {
      expect(JsonPointer.read({'items': []}, '/items/5'), isNull);
    });

    test('empty pointer returns root', () {
      final root = {'a': 1};
      expect(JsonPointer.read(root, ''), root);
    });

    test('unescapes ~0 to ~ and ~1 to /', () {
      final r = JsonPointer.read({'a/b': 1, 'c~d': 2}, '/a~1b');
      expect(r, 1);
      expect(JsonPointer.read({'a/b': 1, 'c~d': 2}, '/c~0d'), 2);
    });

    test('throws on non-pointer-formed string', () {
      expect(() => JsonPointer.read({}, 'no-leading-slash'),
          throwsA(isA<FormatException>()));
    });
  });

  group('JsonPointer.write', () {
    test('writes top-level key', () {
      final r = JsonPointer.write({'foo': 'bar'}, '/foo', 'baz');
      expect(r, {'foo': 'baz'});
    });

    test('creates intermediate map', () {
      final r = JsonPointer.write(<String, dynamic>{}, '/a/b', 42);
      expect(r, {
        'a': {'b': 42}
      });
    });

    test('writes into existing list index', () {
      final r = JsonPointer.write({
        'items': ['x', 'y', 'z']
      }, '/items/1', 'Y');
      expect(r, {
        'items': ['x', 'Y', 'z']
      });
    });

    test('does not mutate input', () {
      final orig = {'a': 1};
      JsonPointer.write(orig, '/a', 2);
      expect(orig, {'a': 1});
    });

    test('empty pointer replaces root', () {
      expect(JsonPointer.write({'a': 1}, '', 'replaced'), 'replaced');
    });
  });
}
