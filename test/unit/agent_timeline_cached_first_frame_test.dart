import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';
import 'package:spacenotes_client/generated/client.dart';
import 'package:spacenotes_client/generated/message.dart';
import 'package:spacenotes_client/providers/chat_providers.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/widgets/chat_message_list.dart';

Message _message(String id, String agentId, int ts) => Message(
      id: id,
      agentId: agentId,
      role: 'assistant',
      text: 'text for $id',
      source: 'agent',
      createdAt: Int64(ts),
    );

Future<SpacetimeDbClient> _offlineClient() =>
    SpacetimeDbClient.create(host: '127.0.0.1:1', database: 'test');

Widget _textItem(BuildContext context, String item) => Text(item);

ProviderContainer _container(SpacetimeDbClient client) {
  final container = ProviderContainer(
    overrides: [spacetimeClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('cached rows produce a populated first frame', () {
    test('timeline is non-empty on the FIRST read after a cache load',
        () async {
      final client = await _offlineClient();
      client.message.loadFromSerializable([
        client.message.decoder.toJson(_message('m1', 'agent-a', 100))!,
        client.message.decoder.toJson(_message('m2', 'agent-a', 200))!,
      ]);

      final container = _container(client);
      final items = container.read(chatTimelineByAgentProvider('agent-a'));

      expect(
        items.length,
        2,
        reason:
            'the very first read of the timeline must already carry the '
            'disk-loaded rows; a cached agent must never see an empty frame',
      );
    });

    test('cache-loaded rows carry no query-set owner, so the SDK reconnect '
        'eviction must never treat them as candidates', () async {
      final client = await _offlineClient();
      client.message.loadFromSerializable([
        client.message.decoder.toJson(_message('m1', 'agent-a', 100))!,
      ]);

      for (final pk in client.message.primaryKeys) {
        expect(
          client.message.ownedKeys(pk),
          isEmpty,
          reason:
              'this zero-owner property is the precondition of the agent '
              'screen spinner bug; the SDK-side guard is proven in '
              'reconnect_cache_load_eviction_test.dart',
        );
      }

      final container = _container(client);
      expect(
        container.read(chatTimelineByAgentProvider('agent-a')),
        hasLength(1),
      );
    });
  });

  group('spinner gate', () {
    testWidgets('an agent with NO cached rows still shows the spinner while '
        'hydrating', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ChatMessageList<String>(
            items: [],
            itemBuilder: _textItem,
            hydrating: true,
            emptyText: 'No messages yet',
          ),
        ),
      ));

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason:
            'a genuinely empty agent with a subscribe in flight must still '
            'show the spinner; deleting the spinner must fail this test',
      );
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('an agent with NO cached rows and nothing pending shows the '
        'empty state, not a spinner', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ChatMessageList<String>(
            items: [],
            itemBuilder: _textItem,
            hydrating: false,
            emptyText: 'No messages yet',
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No messages yet'), findsOneWidget);
    });
  });
}
