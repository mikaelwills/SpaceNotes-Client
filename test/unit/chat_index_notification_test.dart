import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';
import 'package:spacenotes_client/generated/client.dart';
import 'package:spacenotes_client/generated/message.dart';
import 'package:spacenotes_client/generated/permission_request.dart';
import 'package:spacenotes_client/generated/tool_event.dart';
import 'package:spacenotes_client/providers/chat_providers.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';

Message _message(String id, String agentId, int ts) => Message(
      id: id,
      agentId: agentId,
      role: 'assistant',
      text: 'text for $id',
      source: 'agent',
      createdAt: Int64(ts),
    );

ToolEvent _tool(String id, String agentId, int ts) => ToolEvent(
      id: id,
      agentId: agentId,
      tool: 'Bash',
      detail: 'detail for $id',
      startedAt: Int64(ts),
    );

PermissionRequest _permission(String id, String agentId, int ts,
        {String status = 'pending'}) =>
    PermissionRequest(
      id: id,
      agentId: agentId,
      tool: 'Bash',
      input: 'permission for $id',
      status: status,
      createdAt: Int64(ts),
      resolvedAt: null,
    );

Future<SpacetimeDbClient> _offlineClient() =>
    SpacetimeDbClient.create(host: '127.0.0.1:1', database: 'test');

Future<void> _settle(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

ProviderContainer _container(SpacetimeDbClient client) {
  final container = ProviderContainer(
    overrides: [spacetimeClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ChatIndex bucket notification amplification', () {
    test('one new tool_event notifies only the affected agent timeline',
        () async {
      final client = await _offlineClient();
      client.message.insertRow(_message('m-a', 'agent-a', 1));
      client.message.insertRow(_message('m-b', 'agent-b', 2));
      final container = _container(client);

      var aRebuilds = 0;
      var bRebuilds = 0;
      container.listen(
          chatTimelineByAgentProvider('agent-a'), (_, __) => aRebuilds++);
      container.listen(
          chatTimelineByAgentProvider('agent-b'), (_, __) => bRebuilds++);
      await _settle(container);
      aRebuilds = 0;
      bRebuilds = 0;

      client.toolEvent.insertRow(_tool('t-1', 'agent-a', 3));
      await _settle(container);

      expect(aRebuilds, greaterThanOrEqualTo(1),
          reason: 'agent-a gained a tool event; its timeline must recompute');
      expect(bRebuilds, 0,
          reason: "agent-b's timeline content is unchanged; its bucket must "
              'not notify and its provider must not recompute');
    });

    test('re-delivering identical rows notifies no timeline', () async {
      final client = await _offlineClient();
      client.message.insertRow(_message('m-a', 'agent-a', 1));
      client.message.insertRow(_message('m-b', 'agent-b', 2));
      final container = _container(client);

      var aRebuilds = 0;
      var bRebuilds = 0;
      container.listen(
          chatTimelineByAgentProvider('agent-a'), (_, __) => aRebuilds++);
      container.listen(
          chatTimelineByAgentProvider('agent-b'), (_, __) => bRebuilds++);
      await _settle(container);
      aRebuilds = 0;
      bRebuilds = 0;

      client.message.insertRow(_message('m-a', 'agent-a', 1));
      await _settle(container);

      expect(aRebuilds, 0,
          reason: 'a byte-identical re-delivery (resume hydration echo) '
              'changes nothing; no timeline should recompute');
      expect(bRebuilds, 0);
    });

    test('a genuinely new message still reaches the timeline', () async {
      final client = await _offlineClient();
      client.message.insertRow(_message('m-a', 'agent-a', 1));
      final container = _container(client);
      await _settle(container);

      client.message.insertRow(_message('m-a2', 'agent-a', 5));
      await _settle(container);

      final timeline = container.read(chatTimelineByAgentProvider('agent-a'));
      expect(timeline.map((i) => i.id), contains('msg:m-a2'));
    });

    test('a permission status flip removes the item and notifies', () async {
      final client = await _offlineClient();
      client.message.insertRow(_message('m-a', 'agent-a', 1));
      client.permissionRequest.insertRow(_permission('p-1', 'agent-a', 2));
      final container = _container(client);
      await _settle(container);

      expect(
        container
            .read(chatTimelineByAgentProvider('agent-a'))
            .map((i) => i.id),
        contains('perm:p-1'),
      );

      client.permissionRequest
          .updateRow(_permission('p-1', 'agent-a', 2, status: 'allow'));
      await _settle(container);

      expect(
        container
            .read(chatTimelineByAgentProvider('agent-a'))
            .map((i) => i.id),
        isNot(contains('perm:p-1')),
      );
    });

    test('an agent whose rows disappear gets an empty timeline', () async {
      final client = await _offlineClient();
      client.message.insertRow(_message('m-a', 'agent-a', 1));
      client.message.insertRow(_message('m-b', 'agent-b', 2));
      final container = _container(client);

      var bRebuilds = 0;
      container.listen(
          chatTimelineByAgentProvider('agent-b'), (_, __) => bRebuilds++);
      await _settle(container);
      bRebuilds = 0;

      client.message.deleteRow('m-b');
      await _settle(container);

      expect(container.read(chatTimelineByAgentProvider('agent-b')), isEmpty);
      expect(bRebuilds, greaterThanOrEqualTo(1));
    });
  });

  group('ChatIndex rebuild duration at capture scale', () {
    test('measure _rebuild at ~360 msgs / ~1200 tools / 8 agents', () async {
      final client = await _offlineClient();
      const agentCount = 8;
      for (var i = 0; i < 360; i++) {
        client.message
            .insertRow(_message('m-$i', 'agent-${i % agentCount}', i));
      }
      for (var i = 0; i < 1200; i++) {
        client.toolEvent
            .insertRow(_tool('t-$i', 'agent-${i % agentCount}', 1000 + i));
      }
      final container = _container(client);
      container.listen(chatTimelineByAgentProvider('agent-0'), (_, __) {});
      await _settle(container);

      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      addTearDown(() => debugPrint = original);

      const samples = 20;
      for (var i = 0; i < samples; i++) {
        client.toolEvent
            .insertRow(_tool('t-live-$i', 'agent-0', 100000 + i));
        await _settle(container);
      }
      debugPrint = original;

      final tookPattern = RegExp(r'ChatIndex rebuild \| .*took=(\d+)us');
      final durations = [
        for (final line in lines)
          for (final match in tookPattern.allMatches(line))
            int.parse(match.group(1)!),
      ];
      expect(durations.length, greaterThanOrEqualTo(samples),
          reason: 'each inserted tool event must trigger exactly one '
              'instrumented rebuild');

      durations.sort();
      final median = durations[durations.length ~/ 2];
      debugPrint('rebuild durations (us) over ${durations.length} samples: '
          'min=${durations.first} median=$median max=${durations.last}');
    });
  });
}
