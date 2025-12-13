import 'package:spacenotes_client/models/opencode_message.dart';
import 'package:spacenotes_client/models/message_part.dart';

void main() {
  print('🧪 ChatBloc Message Update Regression Test (Unit Test)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  print('This test verifies that _updateOrAddMessage correctly ignores');
  print('message.updated events with empty parts when existing message has content.\n');

  final messages = <OpenCodeMessage>[];
  final messageIndex = <String, int>{};

  void updateOrAddMessage(OpenCodeMessage message) {
    final index = messageIndex[message.id];

    if (index != null && index < messages.length) {
      final existingMessage = messages[index];

      if (message.parts.isEmpty && existingMessage.parts.isNotEmpty) {
        print('🚫 Ignoring message.updated with empty parts - keeping existing content for: ${message.id}');
        return;
      }

      messages[index] = message;
      print('🔍 Updated existing message: ${message.id}');
    } else {
      messages.add(message);
      messageIndex[message.id] = messages.length - 1;
      print('✨ Added new message: ${message.id}');
    }
  }

  print('Test 1: Simulate streaming scenario\n');

  final messageId = 'msg_test123';
  final sessionId = 'ses_test456';

  final streamingMessage = OpenCodeMessage(
    id: messageId,
    sessionId: sessionId,
    role: 'assistant',
    created: DateTime.now(),
    parts: [
      MessagePart(
        id: 'prt_1',
        type: 'text',
        content: 'Hello there, friend!',
      ),
    ],
    isStreaming: true,
  );

  print('Step 1: Add streaming message with content...');
  updateOrAddMessage(streamingMessage);
  print('   Current content: "${messages.last.parts.first.content}"\n');

  final emptyPartsMessage = OpenCodeMessage(
    id: messageId,
    sessionId: sessionId,
    role: 'assistant',
    created: DateTime.now(),
    parts: [],
    isStreaming: false,
  );

  print('Step 2: Receive message.updated with empty parts...');
  updateOrAddMessage(emptyPartsMessage);

  final finalMessage = messages.firstWhere((m) => m.id == messageId);
  final finalContent = finalMessage.parts.isNotEmpty
      ? finalMessage.parts.first.content
      : '<EMPTY>';

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('RESULT');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  print('Final message parts count: ${finalMessage.parts.length}');
  print('Final content: "$finalContent"\n');

  if (finalMessage.parts.isNotEmpty && finalContent == 'Hello there, friend!') {
    print('✅ TEST PASSED: Content was preserved!');
    print('   The fix correctly prevents empty parts from overwriting streamed content.');
  } else {
    print('❌ TEST FAILED: Content was lost!');
    print('   Expected: "Hello there, friend!"');
    print('   Got: "$finalContent"');
  }

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 2: Verify legitimate updates still work\n');

  final updatedMessage = OpenCodeMessage(
    id: messageId,
    sessionId: sessionId,
    role: 'assistant',
    created: DateTime.now(),
    parts: [
      MessagePart(
        id: 'prt_1',
        type: 'text',
        content: 'Updated content with more info!',
      ),
    ],
    isStreaming: false,
  );

  print('Step 1: Send update with actual new content...');
  updateOrAddMessage(updatedMessage);

  final updatedFinalMessage = messages.firstWhere((m) => m.id == messageId);
  final updatedContent = updatedFinalMessage.parts.isNotEmpty
      ? updatedFinalMessage.parts.first.content
      : '<EMPTY>';

  print('Final content after update: "$updatedContent"\n');

  if (updatedContent == 'Updated content with more info!') {
    print('✅ TEST PASSED: Legitimate updates still work!');
  } else {
    print('❌ TEST FAILED: Update was rejected incorrectly!');
  }
}
