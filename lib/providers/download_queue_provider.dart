import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/debug_logger.dart';
import '../services/file_transfer_service.dart';
import '../services/local_download_store.dart';
import 'file_transfer_providers.dart';

enum DownloadJobStatus { queued, downloading, done, failed }

class DownloadJob {
  const DownloadJob({
    required this.path,
    required this.size,
    this.status = DownloadJobStatus.queued,
    this.progress = 0,
    this.error,
  });

  final String path;
  final int size;
  final DownloadJobStatus status;
  final double progress;
  final String? error;

  String get fileName => path.split('/').last;

  bool get isPending =>
      status == DownloadJobStatus.queued ||
      status == DownloadJobStatus.downloading;

  DownloadJob copyWith({
    DownloadJobStatus? status,
    double? progress,
    String? error,
  }) {
    return DownloadJob(
      path: path,
      size: size,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class DownloadQueueState {
  const DownloadQueueState({this.jobs = const [], this.stoppedReason});

  final List<DownloadJob> jobs;
  final String? stoppedReason;

  int get total => jobs.length;
  int get done => jobs.where((j) => j.status == DownloadJobStatus.done).length;
  List<DownloadJob> get failed =>
      jobs.where((j) => j.status == DownloadJobStatus.failed).toList();
  bool get isActive => jobs.any((j) => j.isPending);
  DownloadJob? get current =>
      jobs.where((j) => j.status == DownloadJobStatus.downloading).firstOrNull;
  bool get hasSummary => !isActive && (failed.isNotEmpty || stoppedReason != null);

  bool isPending(String path) => jobs.any((j) => j.path == path && j.isPending);

  DownloadQueueState withJob(String path, DownloadJob Function(DownloadJob) change) {
    return DownloadQueueState(
      jobs: [for (final j in jobs) j.path == path ? change(j) : j],
      stoppedReason: stoppedReason,
    );
  }
}

typedef DownloadRunner = Future<void> Function(
  String path,
  int size,
  void Function(int received, int total) onProgress,
);

class DownloadQueueNotifier extends StateNotifier<DownloadQueueState> {
  DownloadQueueNotifier({
    required DownloadRunner download,
    required Future<void> Function(String path) cancelActive,
    required Future<bool> Function(String path, int size) isComplete,
    required DownloadQueueStore store,
    required void Function(String path) onSettled,
  })  : _download = download,
        _cancelActive = cancelActive,
        _isComplete = isComplete,
        _store = store,
        _onSettled = onSettled,
        super(const DownloadQueueState());

  final DownloadRunner _download;
  final Future<void> Function(String path) _cancelActive;
  final Future<bool> Function(String path, int size) _isComplete;
  final DownloadQueueStore _store;
  final void Function(String path) _onSettled;

  bool _running = false;
  bool _foreground = true;
  Future<void>? _pumping;

  Future<void>? get idle => _pumping;

  Future<void> enqueue(List<QueuedDownload> items) async {
    final fresh = <QueuedDownload>[];
    for (final item in items) {
      if (state.isPending(item.path) || fresh.any((f) => f.path == item.path)) {
        continue;
      }
      if (await _isComplete(item.path, item.size)) {
        await _store.dequeueDownload(item.path);
        continue;
      }
      fresh.add(item);
    }
    if (fresh.isEmpty) return;

    final freshPaths = {for (final f in fresh) f.path};
    final kept = state.isActive
        ? state.jobs.where((j) => !freshPaths.contains(j.path)).toList()
        : const <DownloadJob>[];
    state = DownloadQueueState(jobs: [
      ...kept,
      for (final f in fresh) DownloadJob(path: f.path, size: f.size),
    ]);
    await _store.enqueueDownloads(fresh);
    debugLogger.info('DOWNLOAD_QUEUE', 'Queued', 'added=${fresh.length} total=${state.total}');
    _start();
  }

  Future<void> restore() async {
    final items = await _store.queuedDownloads();
    if (items.isEmpty) return;
    debugLogger.info('DOWNLOAD_QUEUE', 'Restoring queue', 'count=${items.length}');
    await enqueue(items);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) _start();
  }

  Future<void> cancel() async {
    final current = state.current;
    state = const DownloadQueueState();
    await _store.clearDownloadQueue();
    if (current != null) await _cancelActive(current.path);
  }

  void dismiss() {
    if (!state.isActive) state = const DownloadQueueState();
  }

  void _start() {
    if (_running) return;
    _pumping = _pump();
  }

  Future<void> _pump() async {
    _running = true;
    try {
      while (_foreground) {
        final next =
            state.jobs.where((j) => j.status == DownloadJobStatus.queued).firstOrNull;
        if (next == null) break;
        await _run(next);
      }
    } finally {
      _running = false;
    }
    if (!state.isActive && !state.hasSummary) state = const DownloadQueueState();
  }

  Future<void> _run(DownloadJob job) async {
    state = state.withJob(
      job.path,
      (j) => j.copyWith(status: DownloadJobStatus.downloading, progress: 0),
    );
    try {
      await _download(job.path, job.size, (received, total) {
        if (total <= 0) return;
        final value = received / total;
        final current = state.jobs.where((j) => j.path == job.path).firstOrNull;
        if (current == null || value - current.progress < 0.01) return;
        state = state.withJob(job.path, (j) => j.copyWith(progress: value));
      });
      await _settle(job.path, DownloadJobStatus.done);
    } on FileDownloadException catch (e) {
      if (!state.isPending(job.path)) return;
      switch (e.kind) {
        case DownloadFailureKind.superseded:
          await _settle(job.path, DownloadJobStatus.done);
        case DownloadFailureKind.notFound:
          await _drop(job.path);
        case DownloadFailureKind.network:
          if (_foreground) {
            await _stop('Network lost');
          } else {
            state = state.withJob(
              job.path,
              (j) => j.copyWith(status: DownloadJobStatus.queued, progress: 0),
            );
          }
        case DownloadFailureKind.storageFull:
          await _stop('Storage full');
        case DownloadFailureKind.server:
        case DownloadFailureKind.verification:
          await _settle(job.path, DownloadJobStatus.failed, error: e.message);
      }
    } catch (e) {
      if (!state.isPending(job.path)) return;
      await _settle(job.path, DownloadJobStatus.failed, error: e.toString());
    }
  }

  Future<void> _settle(String path, DownloadJobStatus status, {String? error}) async {
    state = state.withJob(
      path,
      (j) => j.copyWith(
        status: status,
        progress: status == DownloadJobStatus.done ? 1 : j.progress,
        error: error,
      ),
    );
    await _store.dequeueDownload(path);
    _onSettled(path);
  }

  Future<void> _drop(String path) async {
    state = DownloadQueueState(
      jobs: state.jobs.where((j) => j.path != path).toList(),
      stoppedReason: state.stoppedReason,
    );
    await _store.dequeueDownload(path);
    _onSettled(path);
  }

  Future<void> _stop(String reason) async {
    final stopped = state.jobs.where((j) => j.isPending).map((j) => j.path).toList();
    state = DownloadQueueState(
      jobs: [
        for (final j in state.jobs)
          j.isPending
              ? j.copyWith(status: DownloadJobStatus.failed, error: reason)
              : j,
      ],
      stoppedReason: reason,
    );
    await _store.clearDownloadQueue();
    stopped.forEach(_onSettled);
    debugLogger.warning('DOWNLOAD_QUEUE', 'Stopped', 'reason=$reason failed=${stopped.length}');
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, DownloadQueueState>((ref) {
  final store = ref.read(localDownloadStoreProvider);
  return DownloadQueueNotifier(
    download: (path, size, onProgress) => ref
        .read(fileTransferServiceProvider)
        .ensureDownloaded(path, size, onProgress: onProgress),
    cancelActive: (path) =>
        ref.read(fileTransferServiceProvider).cancelDownload(path),
    isComplete: (path, size) async =>
        await store.stateFor(path, expectedSize: size) == DownloadState.complete,
    store: store,
    onSettled: (path) => ref.invalidate(downloadStateProvider(path)),
  );
});
