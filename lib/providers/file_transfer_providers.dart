import 'package:flutter_riverpod/flutter_riverpod.dart';
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
