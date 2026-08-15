import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart'
    show InMemoryTokenStore, InMemoryOfflineStorage;

void main() {
  test(
      'a stale token rejected on both lanes is cleared ONCE, so the two '
      'sockets never re-dial as two different anonymous identities', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final tokensSeen = <String?>[];
    server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      tokensSeen.add(auth ?? request.uri.queryParameters['token']);
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

    final tokenlessDials = tokensSeen.where((t) => t == null).length;

    expect(
      tokenlessDials,
      lessThanOrEqualTo(1),
      reason:
          'Each tokenless dial is a socket asking the server to mint a FRESH '
          'anonymous identity. Two lanes each clearing the shared token and '
          're-dialling alone gives one device two identities, which is exactly '
          'what the per-connection presence fix does NOT cover: connected_user '
          'would carry two identities for one device and the online list and '
          'call routing would misbehave. Recovery from a stale token must be a '
          'single repository-level rebuild, not one per lane. '
          '(tokenless dials=$tokenlessDials, all tokens seen=$tokensSeen)',
    );
  });
}
