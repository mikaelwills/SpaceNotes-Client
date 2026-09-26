import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/providers/download_queue_provider.dart';
import 'package:spacenotes_client/services/file_transfer_service.dart';
import 'package:spacenotes_client/services/local_download_store.dart';

class _MemoryQueueStore implements DownloadQueueStore {
  final rows = <String, int>{};

  @override
  Future<void> enqueueDownloads(List<QueuedDownload> items) async {
    for (final i in items) {
      rows.putIfAbsent(i.path, () => i.size);
    }
  }

  @override
  Future<List<QueuedDownload>> queuedDownloads() async => [
        for (final e in rows.entries) QueuedDownload(path: e.key, size: e.value),
      ];

  @override
  Future<void> dequeueDownload(String path) async => rows.remove(path);

  @override
  Future<void> clearDownloadQueue() async => rows.clear();
}

class _Harness {
  _Harness({Set<String>? complete}) : complete = complete ?? {};

  final Set<String> complete;
  final store = _MemoryQueueStore();
  final started = <String>[];
  final settled = <String>[];
  final cancelled = <String>[];
  final gates = <String, Completer<void>>{};
  final failures = <String, Object>{};
  int concurrent = 0;
  int maxConcurrent = 0;

  late final DownloadQueueNotifier queue = DownloadQueueNotifier(
    download: (path, size, onProgress) async {
      started.add(path);
      concurrent++;
      maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
      try {
        onProgress(size ~/ 2, size);
        final gate = gates[path];
        if (gate != null) await gate.future;
        final failure = failures[path];
        if (failure != null) throw failure;
        complete.add(path);
      } finally {
        concurrent--;
      }
    },
    cancelActive: (path) async {
      cancelled.add(path);
      final gate = gates[path];
      failures[path] = FileDownloadException(
        'cancelled',
        kind: DownloadFailureKind.superseded,
      );
      if (gate != null && !gate.isCompleted) gate.complete();
    },
    isComplete: (path, size) async => complete.contains(path),
    store: store,
    onSettled: settled.add,
  );

  Future<void> drain() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      await queue.idle;
    }
  }
}

List<QueuedDownload> _items(List<String> paths) =>
    [for (final p in paths) QueuedDownload(path: p, size: 100)];

void main() {
  group('DownloadQueueNotifier', () {
    test('never queues a file already on the device', () async {
      final h = _Harness(complete: {'A/done.wav'});
      await h.queue.enqueue(_items(['A/done.wav', 'A/new.wav']));
      await h.drain();

      expect(h.started, ['A/new.wav']);
    });

    test('downloads one file at a time, in the order queued', () async {
      final h = _Harness();
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav', 'A/3.wav']));
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/2.wav', 'A/3.wav']);
      expect(h.maxConcurrent, 1);
      expect(h.settled, ['A/1.wav', 'A/2.wav', 'A/3.wav']);
    });

    test('queueing the same file twice downloads it once', () async {
      final h = _Harness();
      h.gates['A/1.wav'] = Completer();
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav', 'B/3.wav']));
      h.gates['A/1.wav']!.complete();
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/2.wav', 'B/3.wav']);
    });

    test('a second folder joins the end of the running queue', () async {
      final h = _Harness();
      h.gates['A/1.wav'] = Completer();
      await h.queue.enqueue(_items(['A/1.wav']));
      await h.queue.enqueue(_items(['B/1.wav']));
      expect(h.queue.state.total, 2);
      h.gates['A/1.wav']!.complete();
      await h.drain();

      expect(h.started, ['A/1.wav', 'B/1.wav']);
    });

    test('a failed file is marked failed and the queue moves on', () async {
      final h = _Harness();
      h.failures['A/1.wav'] = FileDownloadException('HTTP 500');
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/2.wav']);
      expect(h.queue.state.failed.map((j) => j.path), ['A/1.wav']);
      expect(h.store.rows, isEmpty);
    });

    test('a failed file is not retried until queued again', () async {
      final h = _Harness();
      h.failures['A/1.wav'] = FileDownloadException('HTTP 500');
      await h.queue.enqueue(_items(['A/1.wav']));
      await h.drain();
      expect(h.started, ['A/1.wav']);

      h.failures.remove('A/1.wav');
      await h.queue.enqueue(_items(['A/1.wav']));
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/1.wav']);
      expect(h.queue.state.total, 0);
    });

    test('a network drop in the foreground fails the rest and stops', () async {
      final h = _Harness();
      h.failures['A/2.wav'] = FileDownloadException(
        'gone',
        kind: DownloadFailureKind.network,
      );
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav', 'A/3.wav']));
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/2.wav']);
      expect(h.queue.state.failed.map((j) => j.path), ['A/2.wav', 'A/3.wav']);
      expect(h.queue.state.stoppedReason, 'Network lost');
      expect(h.store.rows, isEmpty);
    });

    test('storage full stops the queue and keeps what finished', () async {
      final h = _Harness();
      h.failures['A/2.wav'] = FileDownloadException(
        'full',
        kind: DownloadFailureKind.storageFull,
      );
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav', 'A/3.wav']));
      await h.drain();

      expect(h.queue.state.stoppedReason, 'Storage full');
      expect(h.complete, contains('A/1.wav'));
      expect(h.started, isNot(contains('A/3.wav')));
    });

    test('a connection lost while backgrounded pauses instead of failing', () async {
      final h = _Harness();
      h.gates['A/1.wav'] = Completer();
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      h.queue.setForeground(false);
      h.failures['A/1.wav'] = FileDownloadException(
        'socket closed',
        kind: DownloadFailureKind.network,
      );
      h.gates['A/1.wav']!.complete();
      await h.drain();

      expect(h.queue.state.failed, isEmpty);
      expect(h.queue.state.isActive, isTrue);
      expect(h.started, ['A/1.wav']);

      h.failures.remove('A/1.wav');
      h.gates.remove('A/1.wav');
      h.queue.setForeground(true);
      await h.drain();

      expect(h.started, ['A/1.wav', 'A/1.wav', 'A/2.wav']);
      expect(h.queue.state.total, 0);
    });

    test('cancel stops after the current file and forgets the rest', () async {
      final h = _Harness();
      h.gates['A/1.wav'] = Completer();
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      await Future<void>.delayed(Duration.zero);
      await h.queue.cancel();
      await h.drain();

      expect(h.cancelled, ['A/1.wav']);
      expect(h.started, ['A/1.wav']);
      expect(h.queue.state.total, 0);
      expect(h.store.rows, isEmpty);
    });

    test('a file the viewer takes over counts as done, not failed', () async {
      final h = _Harness();
      h.failures['A/1.wav'] = FileDownloadException(
        'superseded',
        kind: DownloadFailureKind.superseded,
      );
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      await h.drain();

      expect(h.queue.state.failed, isEmpty);
      expect(h.started, ['A/1.wav', 'A/2.wav']);
    });

    test('a file deleted from the vault is dropped without failing', () async {
      final h = _Harness();
      h.failures['A/1.wav'] = FileDownloadException(
        'HTTP 404',
        kind: DownloadFailureKind.notFound,
      );
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));
      await h.drain();

      expect(h.queue.state.failed, isEmpty);
      expect(h.started, ['A/1.wav', 'A/2.wav']);
    });

    test('the queue is persisted until each file settles', () async {
      final h = _Harness();
      h.gates['A/1.wav'] = Completer();
      await h.queue.enqueue(_items(['A/1.wav', 'A/2.wav']));

      expect(h.store.rows.keys, ['A/1.wav', 'A/2.wav']);
      h.gates['A/1.wav']!.complete();
      await h.drain();
      expect(h.store.rows, isEmpty);
    });

    test('a relaunch restores the saved queue and skips what finished', () async {
      final h = _Harness(complete: {'A/1.wav'});
      h.store.rows['A/1.wav'] = 100;
      h.store.rows['A/2.wav'] = 100;
      await h.queue.restore();
      await h.drain();

      expect(h.started, ['A/2.wav']);
      expect(h.store.rows, isEmpty);
    });
  });
}
