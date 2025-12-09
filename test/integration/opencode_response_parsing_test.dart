import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Integration tests for OpenCode response parsing
///
/// Run in record mode to capture real server responses:
/// RECORD_MODE=true dart test/integration/opencode_response_parsing_test.dart
///
/// Run specific test by number (1-7):
/// RECORD_MODE=true TEST_NUMBER=7 dart test/integration/opencode_response_parsing_test.dart
///
/// Run in validation mode (default):
/// dart test/integration/opencode_response_parsing_test.dart

final bool kRecordMode = Platform.environment['RECORD_MODE'] == 'true';
final String? kTestNumber = Platform.environment['TEST_NUMBER'];

void main() async {
  print('🚀 OpenCode Response Parsing Integration Tests\n');

  if (kRecordMode) {
    print('📹 RECORD MODE: Responses will be saved to test/fixtures/opencode_responses/\n');
  }

  final client = http.Client();
  final baseUrl = Platform.environment['OPENCODE_URL'] ?? 'http://localhost:4096';

  print('Connecting to OpenCode server at $baseUrl...');

  String? sessionId;
  String? providerID;
  String? modelID;

  try {
    // Get provider config
    print('\n📡 Getting provider configuration...');
    final configResponse = await client.get(
      Uri.parse('$baseUrl/config'),
      headers: {'Accept': 'application/json'},
    );

    if (configResponse.statusCode == 200) {
      final configData = json.decode(configResponse.body);
      final modelString = configData['model'] as String?;
      if (modelString != null && modelString.contains('/')) {
        final parts = modelString.split('/');
        providerID = parts[0];
        modelID = parts[1];
        print('✅ Provider: $providerID');
        print('✅ Model: $modelID');
      }
    } else {
      throw Exception('Failed to get config: ${configResponse.statusCode}');
    }

    // Create session
    print('\n📝 Creating test session...');
    final sessionResponse = await client.post(
      Uri.parse('$baseUrl/session'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );

    if (sessionResponse.statusCode == 200 || sessionResponse.statusCode == 201) {
      final sessionData = json.decode(sessionResponse.body);
      sessionId = sessionData['id'] as String;
      print('✅ Session created: $sessionId\n');
    } else {
      throw Exception('Failed to create session: ${sessionResponse.statusCode}');
    }

    // Test scenarios
    final testQueries = [
      {'name': 'Simple text', 'query': 'Hello', 'filename': 'simple_text.json'},
      {'name': 'Tool usage', 'query': 'List all .dart files in the test directory', 'filename': 'tool_use.json'},
      {'name': 'File read', 'query': 'Read the pubspec.yaml file and tell me the app name', 'filename': 'file_read.json'},
      {'name': 'Multi-step', 'query': 'Briefly analyze the project structure by looking at lib/ directory', 'filename': 'multi_step.json'},
      {'name': 'Code suggestion', 'query': 'What would you add to a basic Flutter app to make it better?', 'filename': 'code_suggestion.json'},
      {'name': 'Simple question', 'query': 'Explain what Flutter is in one sentence', 'filename': 'simple_question.json'},
      {'name': 'Confirmation prompt', 'query': 'Create a directory called rust and create a file called hello.rs inside it with the content "fn main() { println!("Hello"); }"', 'filename': 'confirmation_prompt.json'},
      {'name': 'Permission request', 'query': 'Delete the rust directory and all its contents using rm -rf', 'filename': 'permission_request.json'},
    ];

    int testNumber = 1;
    int passed = 0;
    int failed = 0;

    // Filter tests if TEST_NUMBER is specified
    final testsToRun = kTestNumber != null
        ? testQueries.where((test) {
            final index = testQueries.indexOf(test) + 1;
            return index == int.tryParse(kTestNumber!);
          }).toList()
        : testQueries;

    if (kTestNumber != null) {
      print('Running test #$kTestNumber only\n');
      testNumber = int.parse(kTestNumber!);
    }

    for (final test in testsToRun) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Test $testNumber/${testQueries.length}: ${test['name']}');
      print('Query: "${test['query']}"');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      try {
        print('⏳ Sending message (30s timeout)...');
        final messageResponse = await client.post(
          Uri.parse('$baseUrl/session/$sessionId/message'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'providerID': providerID,
            'modelID': modelID,
            'parts': [
              {'type': 'text', 'text': test['query']}
            ]
          }),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timed out after 30 seconds - OpenCode server not responding');
          },
        );

        if (messageResponse.statusCode == 200) {
          final responseData = json.decode(messageResponse.body);

          // Check for error in response (multiple formats)
          bool hasError = false;
          String? errorMsg;

          // Format 1: Direct error object
          if (responseData.containsKey('name') && responseData.containsKey('data')) {
            errorMsg = '${responseData['name']} - ${responseData['data']}';
            hasError = true;
          }

          // Format 2: Error nested in info
          if (responseData.containsKey('info') &&
              responseData['info'].containsKey('error')) {
            final error = responseData['info']['error'];
            errorMsg = '${error['name']} - ${error['data']['message']}';
            hasError = true;
          }

          if (hasError) {
            print('❌ Server returned error: $errorMsg');
            print('   This indicates an OpenCode server bug, not a parsing issue\n');

            // Still save the fixture to document the error format
            if (kRecordMode) {
              await _saveFixture(test['filename'] as String, responseData);
            }
            failed++;
          } else {
            // Analyze the response
            _analyzeResponse(test['name'] as String, responseData);

            // Save if in record mode
            if (kRecordMode) {
              await _saveFixture(test['filename'] as String, responseData);
            }

            print('✅ Test passed\n');
            passed++;
          }
        } else {
          print('❌ HTTP ${messageResponse.statusCode}: ${messageResponse.body}\n');
          failed++;
        }
      } catch (e) {
        print('❌ Test failed with exception: $e\n');
        failed++;
      }

      testNumber++;

      // Small delay between tests
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Test Results');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('✅ Passed: $passed');
    print('❌ Failed: $failed');
    print('Total: ${testQueries.length}');

    if (kRecordMode && passed > 0) {
      print('\n💾 Fixtures saved to: test/fixtures/opencode_responses/');
    }

  } catch (e) {
    print('\n❌ Fatal error: $e');
    print('Make sure OpenCode server is running and accessible at $baseUrl');
    exit(1);
  } finally {
    // Cleanup
    if (sessionId != null) {
      try {
        print('\n🧹 Cleaning up session...');
        await client.delete(
          Uri.parse('$baseUrl/session/$sessionId'),
          headers: {'Content-Type': 'application/json'},
        );
        print('✅ Session deleted');
      } catch (e) {
        print('⚠️  Failed to delete session: $e');
      }
    }
    client.close();
  }
}

/// Analyze and print response structure
void _analyzeResponse(String testName, Map<String, dynamic> response) {
  print('📊 Response Analysis:');

  // Check for info object (nested structure)
  final info = response['info'] as Map<String, dynamic>?;
  final messageId = info?['id'] ?? response['id'];
  final sessionId = info?['sessionID'] ?? response['sessionID'] ?? response['sessionId'];
  final role = info?['role'] ?? response['role'];

  print('   Message ID: $messageId');
  print('   Session ID: $sessionId');
  print('   Role: $role');

  // Time info (check both info.time and top-level time)
  final timeData = info?['time'] as Map<String, dynamic>? ?? response['time'] as Map<String, dynamic>?;
  if (timeData != null) {
    print('   Created: ${timeData['created']}');
    print('   Completed: ${timeData['completed']}');
  }

  // Parts analysis
  final parts = response['parts'] as List<dynamic>? ?? [];
  print('   Total Parts: ${parts.length}');

  // Part type breakdown
  final partTypeCounts = <String, int>{};
  for (final part in parts) {
    final type = part['type'] as String;
    partTypeCounts[type] = (partTypeCounts[type] ?? 0) + 1;
  }

  if (partTypeCounts.isNotEmpty) {
    print('   Part Type Breakdown:');
    partTypeCounts.forEach((type, count) {
      print('     - $type: $count');
    });
  }

  // Detailed part info
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i] as Map<String, dynamic>;
    print('\n   Part $i:');
    print('     - Type: ${part['type']}');
    print('     - ID: ${part['id']}');

    final content = part['text'] ?? part['content'];
    if (content != null) {
      final preview = content.toString().length > 60
        ? '${content.toString().substring(0, 60)}...'
        : content.toString();
      print('     - Content: $preview');
    }

    // Check for metadata
    final hasMetadata = part.keys.any((k) =>
      k != 'id' && k != 'type' && k != 'text' && k != 'content'
    );

    if (hasMetadata) {
      print('     - Additional fields: ${part.keys.where((k) =>
        k != 'id' && k != 'type' && k != 'text' && k != 'content'
      ).join(', ')}');
    }
  }

  print('');
}

/// Save response as JSON fixture
Future<void> _saveFixture(String filename, Map<String, dynamic> response) async {
  final fixturesDir = Directory('test/fixtures/opencode_responses');
  if (!await fixturesDir.exists()) {
    await fixturesDir.create(recursive: true);
  }

  final file = File('${fixturesDir.path}/$filename');
  final prettyJson = const JsonEncoder.withIndent('  ').convert(response);

  await file.writeAsString(prettyJson);
  print('💾 Saved fixture: $filename');
}
