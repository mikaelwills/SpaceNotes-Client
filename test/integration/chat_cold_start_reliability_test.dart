import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:spacenotes_client/providers/chat_providers.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';

import 'full_stack_note_reliability_test.dart' show InMemoryTokenStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testHost = '100.84.184.121:5050';
  const testDatabase = 'spacenotes';
  const uuid = Uuid();

  group('Chat Cold-Start Reliability', () {
    testWidgets(
        'REPRO: new sends appear in timeline AFTER backlog hydration on fresh client',
        (tester) async {
      // Unique per-run session id so the backlog on the server is deterministic
      // and scoped to this test.
      final sessionId = 'test-chat-cold-${uuid.v4().substring(0, 8)}@TESTHOST';

      // --- Phase 1: seed server-side backlog with repo A ---
      final repoA = SpacetimeDbNotesRepository(
        host: testHost,
        database: testDatabase,
        authStorage: InMemoryTokenStore(),
      );

      const backlogCount = 10;
      final List<String> seededIds = [];

      await tester.runAsync(() async {
        await repoA.connectAndGetInitialData();
        await Future.delayed(const Duration(milliseconds: 500));

        final clientA = repoA.clientNotifier.value!;
        await clientA.reducers.registerSession(
          id: sessionId,
          baseName: 'test-chat-cold',
          host: 'TESTHOST',
          clientId: 'test-a',
        );

        for (var i = 0; i < backlogCount; i++) {
          final mid = 'seed-${uuid.v4()}';
          seededIds.add(mid);
          await clientA.reducers.pushMessage(
            id: mid,
            sessionId: sessionId,
            role: 'user',
            text: 'backlog $i',
            source: 'flutter',
          );
        }
        // Allow transactions to land
        await Future.delayed(const Duration(seconds: 1));
        repoA.dispose();
      });

      // --- Phase 2: cold-start a fresh repo B (no offline cache carry-over,
      // but server backlog will hydrate via SubscribeApplied before ChatIndex
      // starts listening — same shape as the in-the-wild flake) ---
      final repoB = SpacetimeDbNotesRepository(
        host: testHost,
        database: testDatabase,
        authStorage: InMemoryTokenStore(),
      );

      addTearDown(() async {
        try {
          final client = repoB.clientNotifier.value;
          if (client != null) {
            await client.reducers.endSession(sessionId: sessionId);
          }
        } catch (_) {}
        repoB.dispose();
      });

      await tester.runAsync(() async {
        await repoB.connectAndGetInitialData();
        // Wait for initial subscription to apply and hydrate the message cache.
        await Future.delayed(const Duration(seconds: 2));
      });

      final clientB = repoB.clientNotifier.value;
      expect(clientB, isNotNull, reason: 'repoB failed to connect');
      expect(
        clientB!.message.rows.value
            .where((m) => m.sessionId == sessionId)
            .length,
        greaterThanOrEqualTo(backlogCount),
        reason: 'backlog should be hydrated in repoB cache after connect',
      );

      // Build ChatIndex AFTER hydration — matches the real-world sequence
      // where the chat screen mounts on cold-open and `_chatIndexProvider`
      // constructs AFTER the SDK has already applied the initial subscription.
      final container = ProviderContainer(overrides: [
        notesRepositoryProvider.overrideWithValue(repoB),
      ]);
      addTearDown(container.dispose);

      // Prime the chat index provider (reads as side-effect).
      final initialTimeline =
          container.read(chatTimelineBySessionProvider(sessionId));
      expect(
        initialTimeline.length,
        greaterThanOrEqualTo(backlogCount),
        reason: 'timeline should surface the hydrated backlog',
      );

      // Set up a subscription so we observe timeline updates over time.
      final timelineUpdates = <int>[initialTimeline.length];
      final sub = container.listen<List<ChatItem>>(
        chatTimelineBySessionProvider(sessionId),
        (prev, next) => timelineUpdates.add(next.length),
        fireImmediately: false,
      );
      addTearDown(sub.close);

      // --- Phase 3: send new messages from repoB (the symptom scenario) ---
      const newSendCount = 3;
      final newIds = <String>[];
      await tester.runAsync(() async {
        for (var i = 0; i < newSendCount; i++) {
          final mid = 'post-cold-${uuid.v4()}';
          newIds.add(mid);
          await clientB.reducers.pushMessage(
            id: mid,
            sessionId: sessionId,
            role: 'user',
            text: 'post-cold $i',
            source: 'flutter',
          );
          // Give the server echo time to land
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await Future.delayed(const Duration(seconds: 1));
      });

      // --- Assertion: new messages must surface in the timeline ---
      final finalTimeline =
          container.read(chatTimelineBySessionProvider(sessionId));
      final finalIds = finalTimeline
          .whereType<ChatMessageItem>()
          .map((i) => i.message.id)
          .toSet();

      for (final id in newIds) {
        expect(
          finalIds.contains(id),
          isTrue,
          reason:
              'new message $id sent after cold-start hydration was never observed '
              'by chatTimelineBySessionProvider. '
              'timeline size progression: $timelineUpdates. '
              'final timeline length: ${finalTimeline.length}. '
              'This is the silent cold-start flake — the SDK is reclassifying the '
              'server echo as onUpdate (or suppressing it) because the row was '
              'already present during SubscribeApplied hydration.',
        );
      }

      expect(
        finalTimeline.length,
        greaterThanOrEqualTo(backlogCount + newSendCount),
        reason:
            'timeline should grow by newSendCount after sends; only grew from '
            '${timelineUpdates.first} to ${finalTimeline.length}',
      );
    });
  });
}
