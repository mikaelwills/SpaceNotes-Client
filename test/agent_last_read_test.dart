import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacenotes_client/generated/message.dart';
import 'package:spacenotes_client/providers/agent_list_providers.dart';

Message _msg({String role = 'assistant', String source = ''}) => Message(
      id: 'm',
      agentId: 'a',
      role: role,
      text: 't',
      source: source,
      createdAt: Int64(1),
    );

Future<LastReadNotifier> _loaded() async {
  final n = LastReadNotifier();
  while (!n.state.loaded) {
    await Future<void>.delayed(Duration.zero);
  }
  return n;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('agent without a read mark falls back to the install baseline',
      () async {
    final n = await _loaded();
    expect(n.state.readMarkFor('x@M1MAX'), n.state.baseline);
  });

  test('markRead only moves forward and persists across reloads', () async {
    final n = await _loaded();
    n.markRead('a', 500);
    n.markRead('a', 100);
    expect(n.state.readMarkFor('a'), 500);
    await Future<void>.delayed(Duration.zero);
    final reloaded = await _loaded();
    expect(reloaded.state.readMarkFor('a'), 500);
    expect(reloaded.state.baseline, n.state.baseline);
  });

  test('only final agent answers count as replies', () {
    expect(isAgentReply(_msg(source: 'mcp')), isTrue);
    expect(isAgentReply(_msg(source: 'notice')), isFalse);
    expect(isAgentReply(_msg(role: 'user')), isFalse);
    expect(isAgentReply(_msg(source: 'progress')), isFalse);
    expect(isAgentReply(_msg(source: 'control')), isFalse);
  });
}
