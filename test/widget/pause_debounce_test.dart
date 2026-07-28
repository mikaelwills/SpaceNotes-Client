import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/blocs/config/config_cubit.dart';
import 'package:spacenotes_client/main.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';

class _RecordingRepo extends SpacetimeDbNotesRepository {
  _RecordingRepo() : super(host: '0.0.0.0:5050', database: 'spacenotes');

  int pausedCalls = 0;
  int reconnectCalls = 0;
  bool? lastReconnectForce;

  @override
  Future<void> connectAndGetInitialData() async {}

  @override
  Future<void> handleAppPaused() async {
    pausedCalls++;
  }

  @override
  Future<void> tryReconnect({
    bool resetAttempts = false,
    bool force = false,
  }) async {
    reconnectCalls++;
    lastReconnectForce = force;
  }
}

void _deliverLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<_RecordingRepo> _pumpApp(WidgetTester tester) async {
  final repo = _RecordingRepo();
  final container = ProviderContainer(
    overrides: [notesRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: SpaceNotesApp(configCubit: ConfigCubit(), container: container),
    ),
  );
  await tester.pump();
  _deliverLifecycle(tester, const [AppLifecycleState.resumed]);
  return repo;
}

void main() {
  group('pause teardown debounce', () {
    testWidgets(
        'sub-second background glance does not tear down the connection',
        (tester) async {
      final repo = await _pumpApp(tester);
      final reconnectsBefore = repo.reconnectCalls;

      _deliverLifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(const Duration(milliseconds: 800));
      _deliverLifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();

      expect(
        repo.pausedCalls,
        0,
        reason: 'an 800ms glance off-screen must not tear the socket down; '
            'teardown forces a full reconnect+resubscribe on resume instead '
            'of the cheap checkHealth skip',
      );
      expect(repo.reconnectCalls, reconnectsBefore + 1);
      expect(repo.lastReconnectForce, isTrue);
    });

    testWidgets('a 1.4s background (longest measured glance) survives',
        (tester) async {
      final repo = await _pumpApp(tester);

      _deliverLifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(const Duration(milliseconds: 1400));
      _deliverLifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();

      expect(repo.pausedCalls, 0);
    });

    testWidgets('a sustained background still tears the connection down',
        (tester) async {
      final repo = await _pumpApp(tester);

      _deliverLifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(const Duration(seconds: 10));

      expect(
        repo.pausedCalls,
        1,
        reason: 'the debounce must delay teardown, not disable it - a real '
            'background still needs the clean Disconnected state',
      );

      _deliverLifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
    });

    testWidgets('inactive alone never starts the teardown timer',
        (tester) async {
      final repo = await _pumpApp(tester);

      _deliverLifecycle(tester, const [AppLifecycleState.inactive]);
      await tester.pump(const Duration(seconds: 10));
      _deliverLifecycle(tester, const [AppLifecycleState.resumed]);
      await tester.pump();

      expect(repo.pausedCalls, 0);
    });
  });
}
