import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/genui_note_parser.dart';
import 'package:spacenotes_client/widgets/dashboard/input_widgets.dart';

/// Proves the full data-binding loop a Surface would run:
///   1. Parse a note body into a schema
///   2. Render DashTextField bound to a data key
///   3. User types → schema's data map updates
///   4. Serialize back to a note body
///   5. Re-parse the body → identical schema, value preserved
class _BindingHarness extends StatefulWidget {
  final String initialBody;
  final List<String> bindings;
  const _BindingHarness({
    super.key,
    required this.initialBody,
    required this.bindings,
  });

  @override
  State<_BindingHarness> createState() => _BindingHarnessState();
}

class _BindingHarnessState extends State<_BindingHarness> {
  late Map<String, dynamic> _schema;
  late String _markdown;

  @override
  void initState() {
    super.initState();
    final note = GenuiNoteParser.parse(widget.initialBody)!;
    _schema = note.schema;
    _markdown = note.markdown;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (final key in widget.bindings)
              () {
                final v = GenuiNoteParser.readData(_schema, key);
                return DashTextField(
                  key: ValueKey(key),
                  label: key,
                  value: v is String ? v : '',
                  onChanged: (s) => _onChange(key, s),
                );
              }(),
          ],
        ),
      ),
    );
  }

  String currentBody() => GenuiNoteParser.serialize(
        GenuiNote(schema: _schema, markdown: _markdown),
      );

  void _onChange(String key, String value) {
    setState(() {
      _schema = GenuiNoteParser.writeData(_schema, key, value);
    });
  }
}

void main() {
  testWidgets('typing into DashTextField updates schema and round-trips',
      (tester) async {
    const startBody = '''```genui
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

Markdown below.''';

    final harnessKey = GlobalKey<_BindingHarnessState>();
    await tester.pumpWidget(
      _BindingHarness(
        key: harnessKey,
        initialBody: startBody,
        bindings: const ['notes'],
      ),
    );

    // Initial value rendered
    expect(find.text('old'), findsOneWidget);

    // Type new text
    await tester.enterText(find.byType(TextField), 'new value');
    await tester.pump();

    // Schema's data map updated
    expect(harnessKey.currentState!._schema['data']['notes'], 'new value');

    // Serialized body has the new value
    final body = harnessKey.currentState!.currentBody();
    expect(body, contains('"notes": "new value"'));

    // Components untouched (the bug we most want to catch)
    expect(body, contains('"valueBinding": "notes"'));

    // Markdown half untouched
    expect(body, contains('Markdown below.'));

    // Re-parse the serialized body — full round-trip
    final reparsed = GenuiNoteParser.parse(body)!;
    expect(reparsed.schema['data']['notes'], 'new value');
    expect(reparsed.markdown, 'Markdown below.');
  });

  testWidgets('two TextFields bound to different keys update independently',
      (tester) async {
    const startBody = '''```genui
{
  "data": {
    "a": "alpha",
    "b": "beta"
  }
}
```''';

    final harnessKey = GlobalKey<_BindingHarnessState>();
    await tester.pumpWidget(
      _BindingHarness(
        key: harnessKey,
        initialBody: startBody,
        bindings: const ['a', 'b'],
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'ALPHA-NEW');
    await tester.pump();
    await tester.enterText(fields.at(1), 'BETA-NEW');
    await tester.pump();

    final data = harnessKey.currentState!._schema['data'];
    expect(data, isA<Map>());
    final dataMap = data is Map ? data : const <String, Object?>{};
    expect(dataMap['a'], 'ALPHA-NEW');
    expect(dataMap['b'], 'BETA-NEW');

    // Final body parses cleanly back
    final body = harnessKey.currentState!.currentBody();
    final reparsed = GenuiNoteParser.parse(body)!;
    expect(reparsed.schema['data'], {'a': 'ALPHA-NEW', 'b': 'BETA-NEW'});
  });

  testWidgets('editing data does not corrupt the components tree',
      (tester) async {
    const startBody = '''```genui
{
  "components": [
    {
      "component": "TextField",
      "label": "Notes",
      "valueBinding": "notes"
    },
    {
      "component": "KpiCard",
      "label": "Balance",
      "value": "£1,247"
    }
  ],
  "data": {
    "notes": ""
  }
}
```''';

    final harnessKey = GlobalKey<_BindingHarnessState>();
    await tester.pumpWidget(
      _BindingHarness(
        key: harnessKey,
        initialBody: startBody,
        bindings: const ['notes'],
      ),
    );

    await tester.enterText(find.byType(TextField), 'fresh note');
    await tester.pump();

    final reparsed =
        GenuiNoteParser.parse(harnessKey.currentState!.currentBody())!;
    final componentsRaw = reparsed.schema['components'];
    expect(componentsRaw, isA<List>());
    final components = componentsRaw is List ? componentsRaw : const [];

    expect(components.length, 2);
    final first = components[0];
    expect(first, isA<Map>());
    if (first is Map) {
      expect(first['component'], 'TextField');
      expect(first['valueBinding'], 'notes');
    }
    final second = components[1];
    expect(second, isA<Map>());
    if (second is Map) {
      expect(second['component'], 'KpiCard');
      expect(second['value'], '£1,247');
    }

    final dataRaw = reparsed.schema['data'];
    final data = dataRaw is Map ? dataRaw : const <String, Object?>{};
    expect(data['notes'], 'fresh note');
  });
}
