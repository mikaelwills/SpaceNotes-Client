import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/tool_diff_view.dart';

List<String> _render(List<DiffLine> hunk) => [
      for (final line in hunk)
        '${switch (line.kind) {
          DiffLineKind.removed => '-',
          DiffLineKind.added => '+',
          DiffLineKind.context => ' ',
        }}${line.text}',
    ];

Future<void> _pump(WidgetTester tester, List<List<DiffLine>> hunks) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: ToolDiffView(hunks: hunks)),
    ),
  ));
}

void main() {
  group('toolDiffHunks', () {
    test('an edit keeps shared lines as context around the change', () {
      final hunks = toolDiffHunks({
        'file_path': '/a.ts',
        'old_string': 'a\nb\nc',
        'new_string': 'a\nB\nc',
      });

      expect(hunks, hasLength(1));
      expect(_render(hunks.single), [' a', '-b', '+B', ' c']);
    });

    test('a deletion shows only removed lines', () {
      final hunks = toolDiffHunks({'old_string': 'x\ny', 'new_string': ''});

      expect(_render(hunks.single), ['-x', '-y']);
    });

    test('an edits array gives one hunk per edit', () {
      final hunks = toolDiffHunks({
        'edits': [
          {'old_string': 'one', 'new_string': 'uno'},
          {'old_string': 'two', 'new_string': 'dos'},
        ],
      });

      expect(hunks.map(_render), [
        ['-one', '+uno'],
        ['-two', '+dos'],
      ]);
    });

    test('content shows every line as added', () {
      final hunks = toolDiffHunks({'file_path': '/n.md', 'content': 'a\nb'});

      expect(_render(hunks.single), ['+a', '+b']);
    });

    test('a call with no code gives nothing', () {
      expect(toolDiffHunks({'command': 'ls'}), isEmpty);
      expect(toolDiffHunks({'file_path': '/a.ts'}), isEmpty);
    });
  });

  group('ToolDiffView', () {
    testWidgets('a short diff shows every line and no toggle',
        (tester) async {
      await _pump(tester, toolDiffHunks({'content': 'a\nb\nc'}));

      expect(find.text('+ a'), findsOneWidget);
      expect(find.text('+ c'), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_diff_show_all')), findsNothing);
    });

    testWidgets('a long diff is capped until show all is tapped',
        (tester) async {
      final content = List.generate(40, (i) => 'line $i').join('\n');
      await _pump(tester, toolDiffHunks({'content': content}));

      expect(find.text('+ line 14'), findsOneWidget);
      expect(find.text('+ line 15'), findsNothing);
      expect(find.text('show all 40 lines'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tool_diff_show_all')));
      await tester.pump();

      expect(find.text('+ line 39', skipOffstage: false), findsOneWidget);
      expect(find.text('show less', skipOffstage: false), findsOneWidget);
    });
  });
}
