import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/providers/connection_providers.dart';

void main() {
  test('note-facing screens report the notes lane', () {
    for (final location in [
      '/notes',
      '/notes/folder/Projects',
      '/notes/note/abc-123',
      '/notes/passwords',
      '/settings',
      '/connect',
    ]) {
      expect(connectionLaneForLocation(location), ConnectionLane.notes,
          reason: location);
    }
  });

  test('agent, contact and call screens report the chat lane', () {
    for (final location in [
      '/notes/agents',
      '/notes/agents/workflow-agent@robert',
      '/notes/chat',
      '/notes/users',
      '/call/42',
      '/incoming-call',
    ]) {
      expect(connectionLaneForLocation(location), ConnectionLane.chat,
          reason: location);
    }
  });

  test('a prefix match does not leak across sibling routes', () {
    expect(connectionLaneForLocation('/notes/agentsomething'),
        ConnectionLane.notes);
    expect(connectionLaneForLocation('/notes/chatter'), ConnectionLane.notes);
  });
}
