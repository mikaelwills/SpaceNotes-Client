import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/debug_logger.dart';
import '../services/file_transfer_service.dart';
import '../services/local_download_store.dart';
import 'notes_providers.dart';

final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return FileTransferService(repository);
});

final localDownloadStoreProvider = Provider<LocalDownloadStore>((ref) {
  return LocalDownloadStore();
});

final downloadStateProvider =
    FutureProvider.family<DownloadState, String>((ref, remotePath) async {
  final store = ref.watch(localDownloadStoreProvider);
  return store.stateFor(remotePath);
});

final backgroundDownloadProvider =
    Provider<BackgroundDownloadRunner>((ref) => BackgroundDownloadRunner(ref));

// A viewer's own State is disposed on navigation, losing the ability to
// invalidate providers mid-download — this lives on the provider tree
// instead, which outlives any single screen.
class BackgroundDownloadRunner {
  BackgroundDownloadRunner(this._ref);

  final Ref _ref;

  Future<void> run({
    required String remotePath,
    required int expectedSize,
    required bool Function() mounted,
    required void Function(double progress) onProgress,
  }) async {
    final service = _ref.read(fileTransferServiceProvider);
    try {
      await service.ensureDownloaded(
        remotePath,
        expectedSize,
        onProgress: (received, total) {
          if (total > 0 && mounted()) onProgress(received / total);
        },
      );
      if (mounted()) onProgress(1.0);
    } catch (e, st) {
      debugLogger.error(
          'BACKGROUND_DOWNLOAD', 'Failed: $remotePath', '$e\n$st');
    } finally {
      _ref.invalidate(downloadStateProvider(remotePath));
    }
  }
}
