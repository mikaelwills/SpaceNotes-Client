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

int _sentQuerySetId(Uint8List sent) =>
    sent[5] | (sent[6] << 8) | (sent[7] << 16) | (sent[8] << 24);

Iterable<int> _subscribeIds(List<Uint8List> sent) =>
    sent.where((m) => m[0] == 0).map(_sentQuerySetId);

class _JsonStringDecoder extends RowDecoder<String> {
  @override
  String decode(BsatnDecoder decoder) => decoder.readString();

  @override
  dynamic getPrimaryKey(String row) => row;

  @override
  bool get supportsJsonSerialization => true;

  @override
  Map<String, dynamic>? toJson(String row) => {'id': row};

  @override
  String? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return id is String ? id : null;
  }
}

class _AgentSubscriptionHarness {
  _AgentSubscriptionHarness(this.connection, this.subscriptions) {
    subscriptions.subscriptionsReady.addListener(_onReady);
  }

  final _FakeConnection connection;
  final SubscriptionManager subscriptions;
  final Set<int> deferredUnsubscribes = {};

  Future<int> subscribeAgent(String agentId) => subscriptions.subscribe([
        for (final t in const [
          'message',
          'tool_event',
          'permission_request',
          'question_request',
        ])
          "SELECT * FROM $t WHERE agent_id = '$agentId'",
      ]);

  void unsubscribeAgent(int querySetId) {
    if (!connection.state.isConnected) {
      deferredUnsubscribes.add(querySetId);
      subscriptions.forgetQuerySet(querySetId);
      return;
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
  late _FakeConnection connection;
  late InMemoryOfflineStorage storage;
  late SubscriptionManager subscriptions;
  late _AgentSubscriptionHarness harness;

  setUp(() async {
    connection = _FakeConnection();
    storage = InMemoryOfflineStorage();
    await storage.initialize();
    subscriptions = SubscriptionManager(connection, offlineStorage: storage);
    harness = _AgentSubscriptionHarness(connection, subscriptions);
    subscriptions.cache
        .registerDecoder<String>('message', _JsonStringDecoder());
    subscriptions.cache
        .registerDecoder<String>('space_file', _JsonStringDecoder());
  });

  tearDown(() async {
    harness.dispose();
    await subscriptions.dispose();
  });

  Future<int> primeGlobalsAndAgent() async {
    await connection.connect();
    final globals = subscriptions.subscribe(['SELECT * FROM space_file']);
    final agent = harness.subscribeAgent('a1');
    connection.simulateIncoming(
      _createSubscribeApplied(
        requestId: 0,
        querySetId: 1,
        rowsByTable: {
          'space_file': ['f1'],
        },
      ),
    );
    connection.simulateIncoming(
      _createSubscribeApplied(
        requestId: 0,
        querySetId: 2,
        rowsByTable: {
          'message': ['a1-m1', 'a1-m2'],
        },
      ),
    );
    final agentId = await agent.timeout(_timeout);
    await globals.timeout(_timeout);
    await pumpEventQueue();
    return agentId;
  }

  List<String> snapshotIds(List<Map<String, dynamic>>? rows) =>
      (rows ?? const []).map((r) => r['id']).whereType<String>().toList()
        ..sort();

  test('the deferred unsubscribe must not empty the offline message snapshot',
      () async {
    final agentId = await primeGlobalsAndAgent();

    expect(
      snapshotIds(await storage.loadTableSnapshot('message')),
      ['a1-m1', 'a1-m2'],
      reason: 'the agent chat is persisted while the screen is open',
    );

    await connection.disconnect();
    await pumpEventQueue();

    harness.unsubscribeAgent(agentId);
    await pumpEventQueue();

    connection.clearSent();
    await connection.connect();
    await pumpEventQueue();

    for (final id in _subscribeIds(connection.sentMessages).toSet()) {
      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: id,
          rowsByTable: {
            'space_file': ['f1'],
          },
        ),
      );
    }
    await pumpEventQueue();
    await pumpEventQueue();

    expect(
      snapshotIds(await storage.loadTableSnapshot('message')),
      ['a1-m1', 'a1-m2'],
      reason:
          'dropping the disposed agent set must not evict its cached rows '
          'while offline. _handleSubscribeApplied runs persistTableSnapshots() '
          'with no onlyTables filter, so the first reconnect serializes every '
          'activated table — an emptied message table overwrites the good '
          'disk snapshot and the next cold start opens a blank chat.',
    );
  });

  test('the deferred query set is still absent from the resubscribe batch',
      () async {
    final agentId = await primeGlobalsAndAgent();

    await connection.disconnect();
    await pumpEventQueue();

    harness.unsubscribeAgent(agentId);

    connection.clearSent();
    await connection.connect();
    await pumpEventQueue();

    expect(
      _subscribeIds(connection.sentMessages).toSet(),
      {1},
      reason:
          'the repair must not reintroduce the revival this task exists to '
          'remove — the disposed set stays out of the resubscribe batch',
    );
  });

  test('the flush still sends the wire Unsubscribe once reconnected', () async {
    final agentId = await primeGlobalsAndAgent();

    await connection.disconnect();
    await pumpEventQueue();

    harness.unsubscribeAgent(agentId);
    expect(harness.deferredUnsubscribes, contains(agentId));

    connection.clearSent();
    await connection.connect();
    await pumpEventQueue();

    for (final id in _subscribeIds(connection.sentMessages).toSet()) {
      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: id,
          rowsByTable: {
            'space_file': ['f1'],
          },
        ),
      );
    }
    await pumpEventQueue();
    await pumpEventQueue();

    expect(harness.deferredUnsubscribes, isEmpty,
        reason: 'subscriptionsReady drained the deferral');
    expect(
      connection.sentMessages.where((m) => m[0] == 1).map(_sentQuerySetId),
      contains(agentId),
      reason:
          'the server must still be told to drop the set; the deferral '
          'postpones the wire message, it does not cancel it',
    );
  });

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
      contains('forgetQuerySet(querySetId)'),
      reason:
          'the SDK map entry must be dropped at deferral time so '
          '_onReconnected cannot revive the set',
    );
    expect(
      RegExp(
        r'_chatLane\.deferredUnsubscribes\.add\(querySetId\);\s*'
        r'client\.subscriptions\.unsubscribe',
      ).hasMatch(body),
      isFalse,
      reason:
          'calling unsubscribe on the deferral branch runs '
          '_dropQuerySetEverywhere while offline, evicting the disposed '
          "agent's cached rows; the next reconnect then persists the emptied "
          'table over the offline snapshot',
    );
  });
}
