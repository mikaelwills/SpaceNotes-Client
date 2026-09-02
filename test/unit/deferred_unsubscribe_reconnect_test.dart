import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/codegen.dart';

const _timeout = Duration(seconds: 2);

class _FakeConnection implements SpacetimeDbConnection {
  final List<Uint8List> sentMessages = [];

  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();
  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();
  final StreamController<ConnectionQuality> _qualityController =
      StreamController<ConnectionQuality>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  ConnectionState _state = const Disconnected();

  @override
  NegotiatedWsProtocol get negotiatedProtocol => NegotiatedWsProtocol.v2;

  @override
  Stream<Uint8List> get onMessage => _incomingController.stream;

  @override
  Stream<ConnectionState> get onStateChanged => _stateController.stream;

  @override
  ConnectionState get state => _state;

  @override
  bool get isConnected => _state is Connected;

  @override
  Stream<ConnectionQuality> get connectionQuality => _qualityController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  void send(Uint8List data) {
    if (!isConnected) return;
    sentMessages.add(data);
  }

  @override
  Future<void> connect() async {
    _state = const Connected();
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = const Disconnected();
    _stateController.add(_state);
  }

  @override
  Future<void> reconnect() async => connect();

  @override
  Future<void> retryConnection() async => connect();

  @override
  Future<void> dispose() async {
    await _incomingController.close();
    await _stateController.close();
    await _qualityController.close();
    await _errorController.close();
  }

  @override
  void setKeepAliveWorkInFlight(bool inFlight) {}

  @override
  void enableAutoReconnect(bool enabled) {}

  @override
  void updateToken(String token) {}

  @override
  void clearToken() {}

  @override
  String get host => 'fake://localhost';

  @override
  String get database => 'fake_db';

  @override
  String? get initialToken => null;

  @override
  String? get token => null;

  @override
  bool get ssl => false;

  @override
  ConnectionConfig get config => const ConnectionConfig();

  @override
  Future<void> callReducer(
    String reducerName,
    Uint8List args, {
    int? requestId,
  }) async {
    throw UnimplementedError();
  }

  void simulateIncoming(Uint8List data) => _incomingController.add(data);

  void clearSent() => sentMessages.clear();
}

Uint8List _createSubscribeApplied({
  required int requestId,
  required int querySetId,
  Map<String, List<String>> rowsByTable = const {},
}) {
  final encoder = BsatnEncoder();
  encoder.writeU8(0);
  encoder.writeU8(1);
  encoder.writeU32(requestId);
  encoder.writeU32(querySetId);
  encoder.writeU32(rowsByTable.length);
  for (final entry in rowsByTable.entries) {
    encoder.writeString(entry.key);
    encoder.writeU8(0);
    final rowsEncoder = BsatnEncoder();
    for (final row in entry.value) {
      rowsEncoder.writeString(row);
    }
    final rowsData = rowsEncoder.toBytes();
    final rowSize =
        entry.value.isEmpty ? 0 : rowsData.length ~/ entry.value.length;
    encoder.writeU16(rowSize);
    encoder.writeU32(rowsData.length);
    encoder.writeBytes(rowsData);
  }
  return encoder.toBytes();
}

class _StringDecoder extends RowDecoder<String> {
  @override
  String decode(BsatnDecoder decoder) => decoder.readString();

  @override
  dynamic getPrimaryKey(String row) => row;
}

int _sentQuerySetId(Uint8List sent) => sent[5] |
    (sent[6] << 8) |
    (sent[7] << 16) |
    (sent[8] << 24);

Iterable<int> _subscribeIds(List<Uint8List> sent) =>
    sent.where((m) => m[0] == 0).map(_sentQuerySetId);

class _AgentSubscriptionHarness {
  _AgentSubscriptionHarness(this.connection, this.subscriptions) {
    subscriptions.subscriptionsReady.addListener(_onReady);
  }

  final _FakeConnection connection;
  final SubscriptionManager subscriptions;
  final Set<int> deferredUnsubscribes = {};

  Future<int> subscribeAgent(String agentId) => subscriptions.subscribe(
        [
          for (final t in const [
            'message',
            'tool_event',
            'permission_request',
            'question_request',
          ])
            "SELECT * FROM $t WHERE agent_id = '$agentId'",
        ],
      );

  void unsubscribeAgent(int querySetId) {
    if (!connection.state.isConnected) {
      deferredUnsubscribes.add(querySetId);
    }
    subscriptions.unsubscribe(querySetId);
  }

  void dispose() {
    subscriptions.subscriptionsReady.removeListener(_onReady);
  }

  void _onReady() {
    if (!subscriptions.subscriptionsReady.value) return;
    if (deferredUnsubscribes.isEmpty) return;
    final ids = deferredUnsubscribes.toList();
    deferredUnsubscribes.clear();
    for (final id in ids) {
      subscriptions.unsubscribe(id);
    }
  }
}

void main() {
  test('the harness mirrors the real unsubscribeAgent deferral branch', () {
    final source = File(
      'lib/repositories/spacetimedb_notes_repository.dart',
    ).readAsStringSync();
    final start = source.indexOf('void unsubscribeAgent(int querySetId) {');
    expect(start, isNot(-1), reason: 'unsubscribeAgent not found');
    final body = source.substring(start, source.indexOf('\n  }', start));

    expect(
      body,
      contains('_chatLane.deferredUnsubscribes.add(querySetId)'),
      reason: 'the wire Unsubscribe must still be deferred to flush time, '
          'now on the chat lane that owns the per-agent query sets',
    );
    expect(
      body,
      contains('client.subscriptions.unsubscribe(querySetId)'),
      reason: 'the SDK map entry must be dropped at deferral time',
    );
    expect(
      RegExp(
        r'_chatLane\.deferredUnsubscribes\.add\(querySetId\);\s*return;',
      ).hasMatch(body),
      isFalse,
      reason:
          'an early return on the deferral branch leaves the id in the SDK '
          'map, which _onReconnected then revives as a duplicate query set',
    );
  });

  group('agent screen disposed while disconnected', () {
    late _FakeConnection connection;
    late SubscriptionManager subscriptions;
    late _AgentSubscriptionHarness harness;

    setUp(() {
      connection = _FakeConnection();
      subscriptions = SubscriptionManager(connection);
      harness = _AgentSubscriptionHarness(connection, subscriptions);
    });

    tearDown(() async {
      harness.dispose();
      await subscriptions.dispose();
    });

    test('the deferred query set is NOT revived in the resubscribe batch',
        () async {
      await connection.connect();

      final globals = subscriptions.subscribe(['SELECT * FROM space_file']);
      final agent = harness.subscribeAgent('a1');
      for (var id = 1; id <= 2; id++) {
        connection.simulateIncoming(
          _createSubscribeApplied(requestId: 0, querySetId: id),
        );
      }
      final agentQuerySetId = await agent.timeout(_timeout);
      await globals.timeout(_timeout);
      expect(agentQuerySetId, 2);

      await connection.disconnect();
      await pumpEventQueue();

      harness.unsubscribeAgent(agentQuerySetId);
      expect(
        harness.deferredUnsubscribes,
        contains(agentQuerySetId),
        reason: 'the wire Unsubscribe must still be deferred to flush time',
      );

      connection.clearSent();
      await connection.connect();
      await pumpEventQueue();

      expect(
        _subscribeIds(connection.sentMessages),
        isNot(contains(agentQuerySetId)),
        reason:
            'the agent screen is gone; deferring the unsubscribe must defer '
            'only the wire message, never the intent. Reviving the set makes '
            'a duplicate query set with byte-identical queries, whose empty '
            'response drives _evictReconnectDeletes to empty the chat.',
      );
      expect(_subscribeIds(connection.sentMessages).toSet(), {1});
    });

    test('reopening the agent after the pause leaves ONE set for that agent',
        () async {
      subscriptions.cache.registerDecoder<String>('message', _StringDecoder());

      await connection.connect();

      final globals = subscriptions.subscribe(['SELECT * FROM space_file']);
      final agent = harness.subscribeAgent('a1');
      connection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: 2,
          rowsByTable: {
            'message': ['m1', 'm2'],
          },
        ),
      );
      final firstAgentId = await agent.timeout(_timeout);
      await globals.timeout(_timeout);

      await connection.disconnect();
      await pumpEventQueue();
      harness.unsubscribeAgent(firstAgentId);

      connection.clearSent();
      await connection.connect();
      await pumpEventQueue();

      final reopened = harness.subscribeAgent('a1');
      final revivedIds = _subscribeIds(connection.sentMessages).toSet();
      connection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      for (final id in revivedIds.where((id) => id != 1)) {
        connection.simulateIncoming(
          _createSubscribeApplied(requestId: 0, querySetId: id),
        );
      }
      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: 3,
          rowsByTable: {
            'message': ['m1', 'm2'],
          },
        ),
      );
      final secondAgentId = await reopened.timeout(_timeout);
      await pumpEventQueue();

      expect(
        subscriptions.subscriptionsByQuerySetId.keys,
        isNot(contains(firstAgentId)),
        reason:
            'the disposed screen\'s set must be gone, leaving exactly one set '
            'per open agent screen',
      );
      expect(
        subscriptions.subscriptionsByQuerySetId.keys.toSet(),
        {1, secondAgentId},
      );

      final message = subscriptions.cache.getTableByName('message');
      if (message == null) fail('message table not registered');
      expect(
        message.iter(),
        containsAll(['m1', 'm2']),
        reason: 'the live agent set re-delivered every row, so nothing evicts',
      );
    });
  });
}
