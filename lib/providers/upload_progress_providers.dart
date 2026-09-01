import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UploadJobStatus { uploading, complete, failed }

class UploadJob {
  UploadJob({
    required this.id,
    required this.fileName,
    required this.status,
    this.progress = 0,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.error,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  final String id;
  final String fileName;
  final UploadJobStatus status;
  final double progress;
  final int sentBytes;
  final int totalBytes;
  final String? error;
  final DateTime startedAt;

  UploadJob copyWith({
    UploadJobStatus? status,
    double? progress,
    int? sentBytes,
    int? totalBytes,
    String? error,
  }) {
    return UploadJob(
      id: id,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sentBytes: sentBytes ?? this.sentBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      startedAt: startedAt,
    );
  }
}

class UploadBatchState {
  const UploadBatchState({this.jobs = const []});

  final List<UploadJob> jobs;

  int get total => jobs.length;
  int get completed => jobs.where((j) => j.status == UploadJobStatus.complete).length;
  int get failed => jobs.where((j) => j.status == UploadJobStatus.failed).length;
  bool get isActive => jobs.any((j) => j.status == UploadJobStatus.uploading);

  UploadJob? get activeJob =>
      jobs.where((j) => j.status == UploadJobStatus.uploading).firstOrNull;

  double get currentProgress => activeJob?.progress ?? 0;

  UploadBatchState upsert(UploadJob job) {
    final next = jobs.where((j) => j.id != job.id).toList()..add(job);
    return UploadBatchState(jobs: next);
  }

  UploadBatchState clear() => const UploadBatchState();
}

class UploadBatchNotifier extends StateNotifier<UploadBatchState> {
  UploadBatchNotifier() : super(const UploadBatchState());

  void startBatch(List<({String id, String fileName})> jobs) {
    state = UploadBatchState(
      jobs: jobs
          .map((j) => UploadJob(
                id: j.id,
                fileName: j.fileName,
                status: UploadJobStatus.uploading,
              ))
          .toList(),
    );
  }

  void beginJob(String id) {
    final job = state.jobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    state = state.upsert(job.copyWith(status: UploadJobStatus.uploading));
  }

  void progress(String id, double value, {int sentBytes = 0, int totalBytes = 0}) {
    final job = state.jobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    state = state.upsert(job.copyWith(
      progress: value,
      sentBytes: sentBytes,
      totalBytes: totalBytes,
    ));
  }

  void complete(String id) {
    final job = state.jobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    state = state.upsert(job.copyWith(status: UploadJobStatus.complete, progress: 1));
  }

  void fail(String id, String error) {
    final job = state.jobs.where((j) => j.id == id).firstOrNull;
    if (job == null) return;
    state = state.upsert(job.copyWith(status: UploadJobStatus.failed, error: error));
  }

  void finishBatch() {
    if (!state.isActive) state = state.clear();
  }
}

final uploadBatchProvider =
    StateNotifierProvider<UploadBatchNotifier, UploadBatchState>(
  (ref) => UploadBatchNotifier(),
);
