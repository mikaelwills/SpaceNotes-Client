import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/genui_note_parser.dart';

void main() {
  group('GenuiNoteParser.isFlat', () {
    test('returns true when rootId is present', () {
      expect(
        GenuiNoteParser.isFlat({
          'rootId': 'root',
          'components': [
            {'id': 'root', 'component': 'Column'}
          ]
        }),
        isTrue,
      );
    });

    test('returns true when first component has an id', () {
      expect(
        GenuiNoteParser.isFlat({
          'components': [
            {'id': 'root', 'component': 'Column'}
          ]
        }),
        isTrue,
      );
    });

    test('returns false for legacy nested shape', () {
      expect(
        GenuiNoteParser.isFlat({
          'components': [
            {'component': 'KpiCard', 'label': 'X', 'value': 'Y'}
          ]
        }),
        isFalse,
      );
    });

    test('returns false for empty schema', () {
      expect(GenuiNoteParser.isFlat({}), isFalse);
      expect(GenuiNoteParser.isFlat({'components': []}), isFalse);
    });
  });

  group('GenuiNoteParser.catalogIdOf', () {
    test('returns declared catalogId', () {
      expect(
        GenuiNoteParser.catalogIdOf({'catalogId': 'a2ui/basic'}),
        'a2ui/basic',
      );
    });

    test('returns default when missing', () {
      expect(GenuiNoteParser.catalogIdOf({}), 'spacenotes/v0');
    });

    test('returns default when empty string', () {
      expect(GenuiNoteParser.catalogIdOf({'catalogId': ''}), 'spacenotes/v0');
    });
  });

  group('flat schema round-trip', () {
    test('parses + serializes a minimal flat schema', () {
      const body = '''
```genui
{
  "catalogId": "spacenotes/v0",
  "rootId": "root",
  "components": [
    {
      "id": "root",
      "component": "Column",
      "children": ["title", "offer"]
    },
    {
      "id": "title",
      "component": "Markdown",
      "text": "# Hello"
    },
    {
      "id": "offer",
      "component": "TextField",
      "label": "Offer",
      "value": {"path": "/offer"}
    }
  ],
  "data": {"offer": "£100"}
}
```
''';

      final parsed = GenuiNoteParser.parse(body);
      expect(parsed, isNotNull);
      expect(GenuiNoteParser.isFlat(parsed!.schema), isTrue);
      expect(parsed.schema['rootId'], 'root');
      expect(parsed.schema['catalogId'], 'spacenotes/v0');

      final reSer = GenuiNoteParser.serialize(parsed);
      final reParsed = GenuiNoteParser.parse(reSer);
      expect(reParsed!.schema, parsed.schema);
    });
  });
}
