import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🔧 Tool SSE Events Test');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  print('This test captures SSE events during tool execution to understand');
  print('what events OpenCode sends when tools start vs complete.\n');

  final baseUrl = Platform.environment['OPENCODE_URL'] ?? 'http://100.84.184.121:5053';
  final client = http.Client();
  String? sessionId;

  try {
    print('📡 Connecting to OpenCode server at $baseUrl...');

    final configResponse = await client.get(
      Uri.parse('$baseUrl/config'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 5));

    if (configResponse.statusCode != 200) {
      throw Exception('Failed to connect to server: ${configResponse.statusCode}');
    }

    final configData = json.decode(configResponse.body);
    final modelString = configData['model'] as String?;
    String? providerID;
    String? modelID;

    if (modelString != null && modelString.contains('/')) {
      final parts = modelString.split('/');
      providerID = parts[0];
      modelID = parts[1];
      print('✅ Connected - Provider: $providerID, Model: $modelID\n');
    }

    print('📝 Creating test session...');
    final sessionResponse = await client.post(
      Uri.parse('$baseUrl/session'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );

    if (sessionResponse.statusCode != 200 && sessionResponse.statusCode != 201) {
      throw Exception('Failed to create session: ${sessionResponse.statusCode}');
    }

    final sessionData = json.decode(sessionResponse.body);
    sessionId = sessionData['id'] as String;
    print('✅ Session created: $sessionId\n');

    print('🔌 Connecting to SSE stream...');
    final sseUrl = '$baseUrl/event';
    final sseRequest = http.Request('GET', Uri.parse(sseUrl));
    sseRequest.headers['Accept'] = 'text/event-stream';
    sseRequest.headers['Cache-Control'] = 'no-cache';

    final sseClient = http.Client();
    final sseResponse = await sseClient.send(sseRequest);

    if (sseResponse.statusCode != 200) {
      throw Exception('Failed to connect to SSE: ${sseResponse.statusCode}');
    }

    print('✅ SSE connected\n');

    final allEvents = <Map<String, dynamic>>[];
    final toolEvents = <Map<String, dynamic>>[];
    final completer = Completer<void>();
    int eventCount = 0;

    final sseSubscription = sseResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.startsWith('data:')) {
        final jsonStr = line.substring(5).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final eventData = json.decode(jsonStr) as Map<String, dynamic>;
            final eventType = eventData['type'] as String?;
            eventCount++;

            allEvents.add(eventData);

            if (eventType == 'message.part.updated') {
              final properties = eventData['properties'] as Map<String, dynamic>?;
              final part = properties?['part'] as Map<String, dynamic>?;
              final partType = part?['type'] as String?;

              if (partType == 'tool') {
                toolEvents.add(eventData);
                final toolName = part?['tool'] as String?;
                final state = part?['state'];
                final input = part?['input'];

                print('\n🔧 TOOL EVENT CAPTURED:');
                print('   Tool: $toolName');
                print('   State: $state');
                print('   Has input: ${input != null}');
                print('   Full part data:');
                _printJson(part, indent: '     ');
              } else if (partType == 'text') {
                final text = part?['text'] as String? ?? '';
                final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
                print('📝 Text: "$preview"');
              } else if (partType == 'step-start') {
                print('▶️  Step start');
              } else if (partType == 'step-finish') {
                print('⏹️  Step finish');
              } else {
                print('📦 Part type: $partType');
              }
            } else if (eventType == 'session.idle') {
              print('\n💤 Session idle - response complete');
              if (!completer.isCompleted) {
                completer.complete();
              }
            } else if (eventType == 'message.updated') {
              final properties = eventData['properties'] as Map<String, dynamic>?;
              final info = properties?['info'] as Map<String, dynamic>?;
              final role = info?['role'] as String?;
              if (role == 'assistant') {
                print('📨 message.updated (assistant)');
              }
            }
          } catch (e) {
            print('Parse error: $e');
          }
        }
      }
    });

    print('📤 Sending message that will trigger tool use...');
    print('   Query: "Read the pubspec.yaml file and tell me the app name"\n');

    final messageResponse = await client.post(
      Uri.parse('$baseUrl/session/$sessionId/message'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'providerID': providerID,
        'modelID': modelID,
        'parts': [
          {'type': 'text', 'text': 'Read the pubspec.yaml file and tell me the app name. Use the Read tool.'}
        ]
      }),
    );

    if (messageResponse.statusCode != 200) {
      throw Exception('Failed to send message: ${messageResponse.statusCode}');
    }

    print('✅ Message sent, capturing SSE events...\n');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        print('\n⏰ Timeout waiting for response');
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));
    await sseSubscription.cancel();
    sseClient.close();

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('ANALYSIS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    print('Total SSE events: $eventCount');
    print('Tool events captured: ${toolEvents.length}\n');

    if (toolEvents.isEmpty) {
      print('❌ No tool events were captured!');
      print('   This means OpenCode might not send tool events via SSE,');
      print('   or the query did not trigger a tool call.\n');
    } else {
      print('✅ Tool events captured!\n');

      final states = <String>{};
      for (final event in toolEvents) {
        final part = (event['properties'] as Map?)?['part'] as Map?;
        final state = part?['state'];
        if (state != null) {
          if (state is String) {
            states.add(state);
          } else if (state is Map) {
            states.add(state['status'] ?? state['state'] ?? 'unknown');
          }
        }
      }

      print('Tool states observed: ${states.isEmpty ? "none" : states.join(", ")}');
      print('');

      if (states.contains('running') || states.contains('pending')) {
        print('✅ OpenCode DOES send "running" state events!');
        print('   We should see tools appear before they complete.');
      } else {
        print('⚠️  OpenCode only sends completed tool events.');
        print('   Tools will only appear after execution finishes.');
        print('   The "Working..." indicator is needed for feedback.');
      }
    }

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('FULL TOOL EVENTS (for debugging)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    for (var i = 0; i < toolEvents.length; i++) {
      print('Tool Event ${i + 1}:');
      _printJson(toolEvents[i], indent: '  ');
      print('');
    }

    final fixturesDir = Directory('test/fixtures/opencode_responses');
    if (!await fixturesDir.exists()) {
      await fixturesDir.create(recursive: true);
    }

    final file = File('${fixturesDir.path}/tool_sse_events.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'total_events': eventCount,
      'tool_events': toolEvents,
      'all_events': allEvents,
    }));
    print('\n💾 Full event log saved to: test/fixtures/opencode_responses/tool_sse_events.json');

  } catch (e) {
    print('\n❌ Test failed with error: $e');
    exit(1);
  } finally {
    if (sessionId != null) {
      try {
        print('\n🧹 Cleaning up session...');
        await client.delete(Uri.parse('$baseUrl/session/$sessionId'));
        print('✅ Session deleted');
      } catch (e) {
        print('⚠️  Failed to delete session: $e');
      }
    }
    client.close();
  }
}

void _printJson(dynamic data, {String indent = ''}) {
  final encoder = const JsonEncoder.withIndent('  ');
  final lines = encoder.convert(data).split('\n');
  for (final line in lines) {
    print('$indent$line');
  }
}
