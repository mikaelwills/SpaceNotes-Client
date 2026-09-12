import 'dart:io';

import '../platform/capabilities.dart';
import '../providers/upload_progress_providers.dart';
import 'debug_logger.dart';
import 'file_transfer_service.dart';
import 'local_download_store.dart';

/// What a relaunch found waiting for it.
class PendingTransfers {
  const PendingTransfers({required this.uploads, required this.downloads});

  final List<ResumableUploadRow> uploads;
  final List<String> downloads;

  bool get isEmpty => uploads.isEmpty && downloads.isEmpty;
  int get total => uploads.length + downloads.length;
}

/// Finds transfers that were interrupted by the app stopping.
///
/// Reads only — the caller decides whether to continue them, so a launch never
/// starts network traffic the user did not ask for.
Future<PendingTransfers> findPendingTransfers() async {
  if (!Capabilities.hasFileSystem) {
    return const PendingTransfers(uploads: [], downloads: []);
  }

  final store = LocalDownloadStore();
  try {
    final uploads = await store.pendingUploads();
    final downloads = await store.pendingDownloads();

    if (uploads.isNotEmpty || downloads.isNotEmpty) {
      debugLogger.info(
        'RESUME',
        'Found interrupted transfers',
        'uploads=${uploads.length} downloads=${downloads.length}',
      );
    }
    return PendingTransfers(uploads: uploads, downloads: downloads);
  } catch (e) {
    debugLogger.warning('RESUME', 'Could not read pending transfers', e.toString());
    return const PendingTransfers(uploads: [], downloads: []);
  }
}

/// Continues the uploads in [pending], reporting into the existing progress UI.
///
/// Each one resumes from the server's offset rather than restarting, because
/// [FileTransferService.uploadFile] picks up a stored session for the same
/// file. A failure here is logged and skipped: one dead upload must not stop
/// the rest.
Future<void> resumeUploads(
  PendingTransfers pending,
  FileTransferService service,
  UploadBatchNotifier batch,
) async {
  if (pending.uploads.isEmpty) return;

  batch.startBatch([
    for (final row in pending.uploads)
      (id: row.remotePath, fileName: row.fileName),
  ]);

  for (final row in pending.uploads) {
    final file = File(row.sourcePath);
    if (!await file.exists()) {
      debugLogger.info('RESUME', 'Source file is gone, dropping', row.remotePath);
      batch.fail(row.remotePath, 'The original file is no longer available');
      continue;
    }

    try {
      await service.uploadFile(
        _folderOf(row.remotePath),
        file,
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(
              row.remotePath,
              sent / total,
              sentBytes: sent,
              totalBytes: total,
            );
          }
        },
      );
      batch.complete(row.remotePath);
      debugLogger.info('RESUME', 'Upload finished', row.remotePath);
    } catch (e) {
      debugLogger.warning('RESUME', 'Could not resume upload', '${row.remotePath}: $e');
      batch.fail(row.remotePath, e.toString());
    }
  }
}

String _folderOf(String remotePath) {
  final cut = remotePath.lastIndexOf('/');
  return cut <= 0 ? '' : remotePath.substring(0, cut);
}
