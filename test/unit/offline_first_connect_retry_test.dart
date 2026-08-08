import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart'
    show InMemoryTokenStore, InMemoryOfflineStorage;

Future<int> _closedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<SpacetimeDbNotesRepository> _offlineColdStartRepo() async {
  final repo = SpacetimeDbNotesRepository(
    host: '127.0.0.1:${await _closedPort()}',
    database: 'spacenotes',
    authStorage: InMemoryTokenStore(),
  );
  repo.debugSetOfflineStorage(InMemoryOfflineStorage());
  await repo.initializeOfflineFirst();
  return repo;
}

void main() {
  test(
      'offline cold start: repeated ops re-dial the socket on every call, '
      'bypassing the hasOfflineStorage early return', () async {
    final repo = await _offlineColdStartRepo();
    addTearDown(repo.dispose);

    expect(repo.hasOfflineStorage, isTrue,
        reason: 'the cold-start client must be an offline-capable client');

    final before = repo.debugConnectAttempts;
    for (var i = 0; i < 3; i++) {
      await repo.searchNotes('anything');
    }
    final dials = repo.debugConnectAttempts - before;

    expect(
      dials,
      lessThanOrEqualTo(1),
      reason:
          'an offline-capable client that already failed its first connect must '
          'fall through to the offline-mode early return instead of dialling '
          'again on every note operation (dials=$dials)',
    );
  });

  test('offline cold start: a failed connect does not escape to the caller',
      () async {
    final repo = await _offlineColdStartRepo();
    addTearDown(repo.dispose);

    await expectLater(repo.searchNotes('anything'), completes);

    expect(
      repo.hasOfflineStorage,
      isTrue,
      reason:
          'the SDK now owns initial-connect retry via retryInitialConnect, so '
          'the repo must swallow the failure and stay usable offline rather '
          'than arming a second, duplicate ladder',
    );
  });

  test('offline cold start: the pre-created client still gets dialled once',
      () async {
    final repo = await _offlineColdStartRepo();
    addTearDown(repo.dispose);

    expect(repo.debugConnectAttempts, 0,
        reason: 'initializeOfflineFirst must not touch the socket');

    await repo.searchNotes('anything');

    expect(
      repo.debugConnectAttempts,
      1,
      reason:
          'the post-frame connect path must still drive the cache-hydrated '
          'client through _connectClient exactly once',
    );
  });

  test(
      'a 401 on the offline-first initial connect clears the stale token '
      'instead of being swallowed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final tokensSeen = <String?>[];
    server.listen((request) async {
      tokensSeen.add(request.uri.queryParameters['token']);
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });

    final tokens = InMemoryTokenStore();
    await tokens.saveToken('stale-token-from-a-wiped-database');

    final repo = SpacetimeDbNotesRepository(
      host: '127.0.0.1:${server.port}',
      database: 'spacenotes',
      authStorage: tokens,
    );
    addTearDown(repo.dispose);
    repo.debugSetOfflineStorage(InMemoryOfflineStorage());
    await repo.initializeOfflineFirst();

    await repo.searchNotes('anything');

    expect(
      await tokens.loadToken(),
      isNot('stale-token-from-a-wiped-database'),
      reason:
          'a 401 means the token belongs to a database that no longer exists '
          '(a wipe/republish); leaving it on disk makes every later connect '
          'fail the same way with no recovery path',
    );

    expect(
      tokensSeen.length,
      greaterThan(1),
      reason: 'the 401 handler must actually re-dial, not just clear storage',
    );
  });

  test('resetConnection re-arms the one-shot initial connect', () async {
    final repo = await _offlineColdStartRepo();
    addTearDown(repo.dispose);

    await repo.searchNotes('anything');
    expect(repo.debugConnectAttempts, 1);

    repo.resetConnection();
    repo.debugSetOfflineStorage(InMemoryOfflineStorage());
    await repo.initializeOfflineFirst();
    await repo.searchNotes('anything');

    expect(
      repo.debugConnectAttempts,
      2,
      reason:
          'a rebuilt client (instance switch / auth rebuild) must get its own '
          'initial dial, not inherit the spent one-shot flag',
    );
  });
}
