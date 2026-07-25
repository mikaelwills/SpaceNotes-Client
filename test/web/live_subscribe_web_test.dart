@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart' show ConnectionConfig;
import 'package:spacenotes_client/generated/client.dart';

void main() {
  test('connect + subscribe hydrates note.rows on web', () async {
    final client = await SpacetimeDbClient.create(
      host: '100.84.184.121:5050',
      database: 'spacenotes',
      ssl: false,
      config: const ConnectionConfig(
        pingInterval: Duration(seconds: 4),
        pongTimeout: Duration(seconds: 5),
        autoReconnect: false,
        connectTimeout: Duration(seconds: 5),
      ),
    );

    await client.connect(
      initialSubscriptions: const ['SELECT * FROM space_file'],
      subscriptionTimeout: const Duration(seconds: 15),
    );

    final rows = client.spaceFile.rows.value;
    // ignore: avoid_print
    print('>>> note rows hydrated: ${rows.length}');

    expect(rows, isNotEmpty, reason: 'note.rows should contain >0 rows');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
