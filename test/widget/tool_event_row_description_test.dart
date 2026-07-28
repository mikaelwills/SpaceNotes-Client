import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/generated/tool_event.dart';
import 'package:spacenotes_client/widgets/terminal_message.dart';
import 'package:spacetimedb_sdk/codegen.dart';

ToolEvent _event(String tool, Map<String, dynamic> input) {
  return ToolEvent(
    id: 'tool-1',
    agentId: 'agent@test',
    tool: tool,
    detail: jsonEncode({'tool': tool, 'input': input}),
    startedAt: Int64(0),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ToolEvent event, {
  bool isLatest = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ToolEventRow(event: event, isLatest: isLatest),
      ),
    ),
  );
}

void main() {
  testWidgets('collapsed Agent row shows the description', (tester) async {
    await _pump(
      tester,
      _event('Agent', {
        'description': 'Investigate the renderer',
        'subagent_type': 'general-purpose',
        'run_in_background': true,
        'prompt': 'A very long prompt that must never appear on the row',
      }),
    );

    expect(
      find.textContaining('Agent  Investigate the renderer'),
      findsOneWidget,
    );
    expect(find.textContaining('very long prompt'), findsNothing);
  });

  testWidgets('expanded Agent row shows description and subagent type',
      (tester) async {
    await _pump(
      tester,
      _event('Agent', {
        'description': 'Investigate the renderer',
        'subagent_type': 'general-purpose',
      }),
      isLatest: true,
    );

    expect(
      find.textContaining('Investigate the renderer (general-purpose)'),
      findsOneWidget,
    );
  });

  testWidgets('long description is truncated when collapsed', (tester) async {
    final longDescription = 'x' * 80;
    await _pump(tester, _event('Agent', {'description': longDescription}));

    expect(find.textContaining('Agent  ${'x' * 60}…'), findsOneWidget);
    expect(find.textContaining('x' * 61), findsNothing);
  });

  testWidgets('truncation does not split a surrogate pair in a description',
      (tester) async {
    await _pump(tester, _event('Agent', {'description': 'a${'🎉' * 40}'}));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Agent  a🎉'), findsOneWidget);
  });

  testWidgets('truncation does not split a surrogate pair in a command',
      (tester) async {
    await _pump(tester, _event('Bash', {'command': 'a${'🎉' * 40}'}));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Bash  a🎉'), findsOneWidget);
  });

  testWidgets('Bash row still shows command, not description',
      (tester) async {
    await _pump(
      tester,
      _event('Bash', {
        'command': 'flutter analyze',
        'description': 'Run static analysis',
      }),
    );

    expect(find.textContaining('Bash  flutter analyze'), findsOneWidget);
    expect(find.textContaining('Run static analysis'), findsNothing);
  });

  testWidgets('input without any known key still renders bare tool name',
      (tester) async {
    await _pump(tester, _event('SomeTool', {'other': 1}));

    expect(find.text('SomeTool'), findsOneWidget);
  });
}
