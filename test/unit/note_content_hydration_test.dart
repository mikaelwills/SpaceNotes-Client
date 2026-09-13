// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/codegen.dart';
import 'package:spacenotes_client/generated/client.dart';
import 'package:spacenotes_client/generated/file_content.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';

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
}

Uint8List _createSubscribeApplied({
  required int requestId,
  required int querySetId,
}) {
  final encoder = BsatnEncoder();
  encoder.writeU8(0);
  encoder.writeU8(1);
  encoder.writeU32(requestId);
  encoder.writeU32(querySetId);
  encoder.writeU32(0);
  return encoder.toBytes();
}

int _sentQuerySetId(Uint8List sent) =>
    sent[5] | (sent[6] << 8) | (sent[7] << 16) | (sent[8] << 24);

Iterable<int> _subscribeIds(List<Uint8List> sent) =>
    sent.where((m) => m[0] == 0).map(_sentQuerySetId);

const _fileContentQuery = "SELECT * FROM file_content WHERE file_id = 'f1'";

class _FakeRepo extends SpacetimeDbNotesRepository {
  _FakeRepo() : super(host: '0.0.0.0:5050', database: 'spacenotes');

  final applied = ValueNotifier<Set<int>>(const {});
  final subscribed = Completer<int?>();
  final unsubscribed = <int>[];

  @override
  ValueListenable<Set<int>> get appliedNotesQuerySets => applied;

  @override
  Future<int?> subscribeFileContent(String fileId) => subscribed.future;

  @override
  void unsubscribeFileContent(int querySetId) {
    unsubscribed.add(querySetId);
  }
}

Future<SpacetimeDbClient> _offlineClient() =>
    SpacetimeDbClient.create(host: '127.0.0.1:1', database: 'test');

Future<void> _settle(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

({ProviderContainer container, _FakeRepo repo}) _harness(
  SpacetimeDbClient client,
) {
  final repo = _FakeRepo();
  final container = ProviderContainer(
    overrides: [
      notesRepositoryProvider.overrideWithValue(repo),
      notesClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  container.listen(noteContentProvider('f1'), (_, __) {});
  container.listen(noteContentHydratedProvider('f1'), (_, __) {});
  return (container: container, repo: repo);
}

bool _hydrated(ProviderContainer container) => container
    .read(noteContentHydratedProvider('f1'))
    .maybeWhen(data: (v) => v, orElse: () => false);

void main() {
  group('SDK contract the hydration signal relies on', () {
    late _FakeConnection connection;
    late SubscriptionManager subscriptions;
    late Set<int> seenApplied;
    late StreamSubscription<void> appliedSub;

    setUp(() {
      connection = _FakeConnection();
      subscriptions = SubscriptionManager(connection);
      seenApplied = {};
      appliedSub = subscriptions.onSubscribeApplied
          .listen((applied) => seenApplied.add(applied.querySetId));
    });

    tearDown(() async {
      await appliedSub.cancel();
      await subscriptions.dispose();
    });

    test('onSubscribeApplied carries the id BEFORE subscribe() resolves',
        () async {
      await connection.connect();
      final pending = subscriptions.subscribe([_fileContentQuery]);
      connection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      final qsId = await pending.timeout(_timeout);

      expect(qsId, 1);
      expect(
        seenApplied,
        contains(1),
        reason: 'the applied event must be observable at the moment '
            'subscribe() resolves, or the repository span would log '
            'a real apply as a dropped one',
      );
    });

    test('a disconnect resolves subscribe() with NO applied event', () async {
      await connection.connect();
      final pending = subscriptions.subscribe([_fileContentQuery]);
      await connection.disconnect();
      final qsId = await pending.timeout(_timeout);

      expect(qsId, 1, reason: 'the SDK resolves rather than throws');
      expect(
        seenApplied,
        isNot(contains(1)),
        reason: 'no rows were applied, so nothing may report hydrated',
      );
    });

    test('reconnect resubscribes the same id and applies it', () async {
      await connection.connect();
      final pending = subscriptions.subscribe([_fileContentQuery]);
      await connection.disconnect();
      await pending.timeout(_timeout);
      connection.sentMessages.clear();

      await connection.connect();
      await pumpEventQueue();
      expect(_subscribeIds(connection.sentMessages), contains(1));

      connection.simulateIncoming(
        _createSubscribeApplied(requestId: 0, querySetId: 1),
      );
      await pumpEventQueue();
      expect(seenApplied, contains(1));
    });
  });

  group('note content hydration', () {
    test('a real body shows once its query set is applied', () async {
      final client = await _offlineClient();
      client.fileContent.loadFromSerializable([
        FileContent(fileId: 'f1', content: 'hello').toJson(),
      ]);
      final h = _harness(client);

      h.repo.applied.value = {7};
      h.repo.subscribed.complete(7);
      await _settle(h.container);

      expect(h.container.read(noteContentProvider('f1')), 'hello');
      expect(_hydrated(h.container), isTrue);
    });

    test('a file with genuinely no row hydrates as empty', () async {
      final client = await _offlineClient();
      final h = _harness(client);

      h.repo.applied.value = {7};
      h.repo.subscribed.complete(7);
      await _settle(h.container);

      expect(h.container.read(noteContentProvider('f1')), '');
      expect(_hydrated(h.container), isTrue);
    });

    test('a subscribe that resolved on disconnect stays unhydrated',
        () async {
      final client = await _offlineClient();
      final h = _harness(client);

      h.repo.subscribed.complete(7);
      await _settle(h.container);

      expect(
        h.container.read(noteContentProvider('f1')),
        isNull,
        reason: 'an editor seeded with \'\' here would autosave over the '
            'real body once the row arrives',
      );
      expect(_hydrated(h.container), isFalse);
    });

    test('hydration recovers when the resubscribe applies', () async {
      final client = await _offlineClient();
      final h = _harness(client);

      h.repo.subscribed.complete(7);
      await _settle(h.container);
      expect(_hydrated(h.container), isFalse);

      client.fileContent.loadFromSerializable([
        FileContent(fileId: 'f1', content: 'hello').toJson(),
      ]);
      h.repo.applied.value = {7};
      await _settle(h.container);

      expect(_hydrated(h.container), isTrue);
      expect(h.container.read(noteContentProvider('f1')), 'hello');
    });

    test('an unrelated apply does not flip an unapplied set to hydrated',
        () async {
      final client = await _offlineClient();
      final h = _harness(client);

      h.repo.subscribed.complete(7);
      await _settle(h.container);
      h.repo.applied.value = {3};
      await _settle(h.container);

      expect(_hydrated(h.container), isFalse);
      expect(h.container.read(noteContentProvider('f1')), isNull);
    });
  });
}
