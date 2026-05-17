import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/genui_note_parser.dart';

void main() {
  group('GenuiNoteParser.parse', () {
    test('returns null when no genui block present', () {
      expect(GenuiNoteParser.parse(''), isNull);
      expect(GenuiNoteParser.parse('just markdown'), isNull);
      expect(GenuiNoteParser.parse('```dart\nprint("hi");\n```'), isNull);
    });

    test('returns null when genui block contains invalid JSON', () {
      const body = '```genui\nnot json at all\n```';
      expect(GenuiNoteParser.parse(body), isNull);
    });

    test('returns null when genui block parses to non-object', () {
      const body = '```genui\n[1,2,3]\n```';
      expect(GenuiNoteParser.parse(body), isNull);
    });

    test('parses genui-only body (no markdown)', () {
      const body = '```genui\n{"data":{"x":1}}\n```';
      final note = GenuiNoteParser.parse(body)!;
      expect(note.schema, {
        'data': {'x': 1}
      });
      expect(note.markdown, isEmpty);
    });

    test('parses genui + markdown body', () {
      const body = '```genui\n{"data":{"notes":"hello"}}\n```\n\n# Title\n\nSome prose.';
      final note = GenuiNoteParser.parse(body)!;
      expect(note.schema, {
        'data': {'notes': 'hello'}
      });
      expect(note.markdown, '# Title\n\nSome prose.');
    });

    test('parses pretty-printed JSON inside the block', () {
      const body = '```genui\n{\n  "components": [],\n  "data": {\n    "notes": "hi"\n  }\n}\n```';
      final note = GenuiNoteParser.parse(body)!;
      expect(note.schema['data'], {'notes': 'hi'});
    });

    test('tolerates CRLF line endings', () {
      const body = '```genui\r\n{"data":{"a":1}}\r\n```\r\n\r\nbody';
      final note = GenuiNoteParser.parse(body)!;
      expect(note.schema, {
        'data': {'a': 1}
      });
      expect(note.markdown, isNot(contains('```genui')));
    });

    test('preserves unicode in data values', () {
      const body =
          '```genui\n{"data":{"emoji":"🚀","rtl":"שלום","combining":"é"}}\n```';
      final note = GenuiNoteParser.parse(body)!;
      expect(note.schema['data']['emoji'], '🚀');
      expect(note.schema['data']['rtl'], 'שלום');
      expect(note.schema['data']['combining'], 'é');
    });
  });

  group('GenuiNoteParser.serialize', () {
    test('emits canonical pretty-printed form for genui-only', () {
      const expected = '''```genui
{
  "data": {
    "x": 1
  }
}
```''';
      final out = GenuiNoteParser.serialize(const GenuiNote(
        schema: {
          'data': {'x': 1}
        },
        markdown: '',
      ));
      expect(out, expected);
    });

    test('emits blank line between block and markdown body', () {
      const expected = '''```genui
{
  "data": {}
}
```

# Hello''';
      final out = GenuiNoteParser.serialize(const GenuiNote(
        schema: {'data': <String, dynamic>{}},
        markdown: '# Hello',
      ));
      expect(out, expected);
    });
  });

  group('round-trip property (canonical form)', () {
    /// Round-trip: serialize(parse(body)) == body when body is already canonical.
    void expectStable(String body) {
      final parsed = GenuiNoteParser.parse(body);
      expect(parsed, isNotNull, reason: 'failed to parse: $body');
      final out = GenuiNoteParser.serialize(parsed!);
      expect(out, equals(body),
          reason: 'round-trip changed body.\nin:\n$body\nout:\n$out');
    }

    test('canonical genui-only', () {
      expectStable('```genui\n{\n  "data": {\n    "x": 1\n  }\n}\n```');
    });

    test('canonical genui + markdown', () {
      expectStable(
          '```genui\n{\n  "data": {\n    "notes": "hello"\n  }\n}\n```\n\n# Title\n\nProse.');
    });

    test('canonical empty data', () {
      expectStable('```genui\n{\n  "data": {}\n}\n```');
    });

    test('canonical with components + data', () {
      expectStable(
          '```genui\n{\n  "components": [\n    {\n      "component": "TextField",\n      "valueBinding": "notes"\n    }\n  ],\n  "data": {\n    "notes": ""\n  }\n}\n```');
    });
  });

  group('parse → mutate data → serialize (the real edit flow)', () {
    test('editing one data field leaves components untouched', () {
      const body = '''```genui
{
  "components": [
    {
      "component": "TextField",
      "valueBinding": "notes"
    }
  ],
  "data": {
    "notes": "old"
  }
}
```

# Heading

Below prose.''';

      final note = GenuiNoteParser.parse(body)!;
      final newSchema = GenuiNoteParser.writeData(note.schema, 'notes', 'new');
      final out = GenuiNoteParser.serialize(
          note.copyWith(schema: newSchema));

      // Components survived
      expect(out, contains('"valueBinding": "notes"'));
      // Data was updated
      expect(out, contains('"notes": "new"'));
      expect(out, isNot(contains('"notes": "old"')));
      // Markdown survived intact
      expect(out, contains('# Heading'));
      expect(out, contains('Below prose.'));
    });

    test('editing markdown half leaves schema untouched', () {
      const body = '''```genui
{
  "data": {
    "notes": "kept"
  }
}
```

original prose''';

      final note = GenuiNoteParser.parse(body)!;
      final edited = note.copyWith(markdown: 'edited prose');
      final out = GenuiNoteParser.serialize(edited);

      expect(out, contains('"notes": "kept"'));
      expect(out, endsWith('edited prose'));
      expect(out, isNot(contains('original prose')));
    });

    test('writeData creates data map if missing', () {
      final result = GenuiNoteParser.writeData({}, 'x', 1);
      expect(result, {
        'data': {'x': 1}
      });
    });

    test('writeData returns a new map, does not mutate input', () {
      final original = <String, dynamic>{
        'data': {'a': 1}
      };
      final originalDataSource = original['data'];
      final originalDataMap = originalDataSource is Map
          ? Map<String, dynamic>.from(originalDataSource)
          : <String, dynamic>{};
      final copy = Map<String, dynamic>.from(original);
      copy['data'] = originalDataMap;

      final result = GenuiNoteParser.writeData(original, 'a', 2);
      expect(result['data'], {'a': 2});
      // Original is unchanged
      expect(original['data'], copy['data']);
    });
  });

  group('edge cases that must not break the existing flow', () {
    test('a regular markdown note (no genui block) parses to null', () {
      const body = '# Just a normal note\n\nWith some text.';
      expect(GenuiNoteParser.parse(body), isNull);
    });

    test('a markdown note containing a non-genui fenced block parses to null',
        () {
      const body = '```python\nprint("hi")\n```\n\nNormal note.';
      expect(GenuiNoteParser.parse(body), isNull);
    });

    test('serialize preserves data values containing backticks', () {
      const note = GenuiNote(
        schema: {
          'data': {'code': 'print(`hello`)'}
        },
        markdown: '',
      );
      final out = GenuiNoteParser.serialize(note);
      final reparsed = GenuiNoteParser.parse(out)!;
      expect(reparsed.schema['data']['code'], 'print(`hello`)');
    });

    test('readData returns null when key missing', () {
      expect(
          GenuiNoteParser.readData({
            'data': {'a': 1}
          }, 'missing'),
          isNull);
    });

    test('readData returns null when data map missing entirely', () {
      expect(GenuiNoteParser.readData({}, 'x'), isNull);
    });
  });
}
