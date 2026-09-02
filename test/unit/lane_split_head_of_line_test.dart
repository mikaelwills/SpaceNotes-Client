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

SubscriptionManager _manager(_FakeConnection connection) {
  final manager = SubscriptionManager(connection);
  for (final table in const [
    'space_file',
    'folder',
    'agent',
    'message',
  ]) {
    manager.cache.registerDecoder<String>(table, _JsonStringDecoder());
  }
  return manager;
}

/// Resubscribes on reconnect and reports whether the chat query set became
/// ready while the notes set was still outstanding.
Future<void> _reconnect(_FakeConnection connection) async {
  await connection.disconnect();
  await pumpEventQueue();
  connection.clearSent();
  await connection.connect();
  await pumpEventQueue();
}

void main() {
  group('head-of-line blocking on a shared socket', () {
    test(
        'BASELINE: one socket - the chat set cannot report ready until the '
        'notes snapshot applies', () async {
      final connection = _FakeConnection();
      final manager = _manager(connection);
      await connection.connect();
      await pumpEventQueue();

      final notesPending = manager.subscribe(
        ['SELECT * FROM space_file', 'SELECT * FROM folder'],
      );
      final chatPending = manager.subscribe(['SELECT * FROM agent']);
      for (final id in [1, 2]) {
        connection.simulateIncoming(
          _createSubscribeApplied(requestId: 0, querySetId: id),
        );
      }
      final notesSet = await notesPending.timeout(_timeout);
      final chatSet = await chatPending.timeout(_timeout);
      await pumpEventQueue();
      expect(manager.subscriptionsReady.value, isTrue);

      await _reconnect(connection);

      final resent = _subscribeIds(connection.sentMessages).toSet();
      expect(resent, containsAll([notesSet, chatSet]),
          reason: 'both sets ride the same socket on reconnect');

      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: chatSet,
          rowsByTable: {
            'agent': ['a1'],
          },
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        manager.subscriptionsReady.value,
        isFalse,
        reason: 'THE BUG: chat has fully applied, but the shared manager '
            'withholds ready until every set applies - so anything keyed on '
            'this flag waits on the 6.38MB notes frame',
      );

      connection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: notesSet,
          rowsByTable: {
            'space_file': ['f1'],
          },
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(manager.subscriptionsReady.value, isTrue,
          reason: 'ready only arrives once the notes snapshot has applied');

      await manager.dispose();
      await connection.dispose();
    });

    test(
        'SPLIT: two sockets - the chat lane reports ready while the notes '
        'snapshot is still outstanding', () async {
      final notesConnection = _FakeConnection();
      final chatConnection = _FakeConnection();
      final notesManager = _manager(notesConnection);
      final chatManager = _manager(chatConnection);

      await notesConnection.connect();
      await chatConnection.connect();
      await pumpEventQueue();

      final notesPending = notesManager.subscribe(
        ['SELECT * FROM space_file', 'SELECT * FROM folder'],
      );
      final chatPending = chatManager.subscribe(['SELECT * FROM agent']);
      notesConnection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      chatConnection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      await notesPending.timeout(_timeout);
      final chatSet = await chatPending.timeout(_timeout);
      await pumpEventQueue();

      await _reconnect(notesConnection);
      await _reconnect(chatConnection);

      String sentQueries(_FakeConnection c) =>
          c.sentMessages.map(String.fromCharCodes).join();

      expect(sentQueries(notesConnection), contains('space_file'));
      expect(
        sentQueries(notesConnection),
        isNot(contains('FROM agent')),
        reason: 'the chat set must not be resent on the notes socket',
      );
      expect(sentQueries(chatConnection), contains('FROM agent'));
      expect(
        sentQueries(chatConnection),
        isNot(contains('space_file')),
        reason: 'the notes set must not be resent on the chat socket',
      );

      chatConnection.simulateIncoming(
        _createSubscribeApplied(
          requestId: 0,
          querySetId: chatSet,
          rowsByTable: {
            'agent': ['a1'],
          },
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        chatManager.subscriptionsReady.value,
        isTrue,
        reason: 'THE FIX: chat hydration completes on its own socket without '
            'waiting for the notes snapshot',
      );
      expect(
        notesManager.subscriptionsReady.value,
        isFalse,
        reason: 'the notes lane is still hydrating, proving the chat lane did '
            'not simply win a race - it is genuinely independent',
      );

      await notesManager.dispose();
      await chatManager.dispose();
      await notesConnection.dispose();
      await chatConnection.dispose();
    });
  });

  test(
      'the two lanes cannot share an offline cache directory, so their '
      'retention tag sidecars never collide', () {
    final source = File(
      'lib/repositories/spacetimedb_notes_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(r"'${appDir.path}/spacenotes_offline$suffix'"),
      reason: 'the cache path must be parameterised by lane',
    );

    final suffixes = RegExp(r"storageSuffix: '(_[a-z]+)'")
        .allMatches(source)
        .map((m) => m.group(1))
        .toList();
    expect(suffixes, containsAll(['_notes', '_chat']));
    expect(
      suffixes.toSet().length,
      suffixes.length,
      reason: 'basePath is the ONLY thing scoping the __tags__ sidecars, so '
          'two lanes sharing a suffix would write the same sidecar file',
    );
  });
}
