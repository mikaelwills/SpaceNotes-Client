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

  test('agent and calling screens report the chat lane', () {
    for (final location in [
      '/agents',
      '/agents/chat',
      '/agents/workflow-agent@robert',
      '/calling',
      '/calling/incoming',
      '/calling/42',
    ]) {
      expect(connectionLaneForLocation(location), ConnectionLane.chat,
          reason: location);
    }
  });

  test('a prefix match does not leak across sibling routes', () {
    expect(connectionLaneForLocation('/agentsomething'), ConnectionLane.notes);
    expect(connectionLaneForLocation('/callingcard'), ConnectionLane.notes);
    expect(connectionLaneForLocation('/notes/agents'), ConnectionLane.notes);
  });
}
