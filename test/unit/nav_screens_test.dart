import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/widgets/adaptive/nav_cycle.dart';

void main() {
  group('navScreensFor', () {
    test('everything on shows every destination', () {
      expect(
        navScreensFor(agentsEnabled: true, passwordsEnabled: true),
        ['/notes', '/agents/chat', '/agents', '/notes/passwords'],
      );
    });

    test('password manager off drops only the passwords destination', () {
      expect(
        navScreensFor(agentsEnabled: true, passwordsEnabled: false),
        ['/notes', '/agents/chat', '/agents'],
      );
    });

    test('agents off drops only the agent destinations', () {
      expect(
        navScreensFor(agentsEnabled: false, passwordsEnabled: true),
        ['/notes', '/notes/passwords'],
      );
    });

    test('both off leaves notes alone', () {
      expect(
        navScreensFor(agentsEnabled: false, passwordsEnabled: false),
        ['/notes'],
      );
    });
  });
}
