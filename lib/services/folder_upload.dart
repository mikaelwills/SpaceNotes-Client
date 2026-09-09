import 'dart:io';

import 'package:flutter/material.dart';

import '../providers/upload_progress_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/sn_button.dart';
import '../widgets/primitives/sn_dialog.dart';
import 'debug_logger.dart';
import 'file_transfer_service.dart';

class FolderUploadResult {
  const FolderUploadResult({required this.skipped, required this.failed});

  final List<String> skipped;
  final List<String> failed;

  bool get hasSkipped => skipped.isNotEmpty;
}

Future<FolderUploadResult> uploadFilesToFolder({
  required FileTransferService service,
  required UploadBatchNotifier batch,
  required String folderPath,
  required List<File> files,
}) async {
  final skipped = <String>[];
  final failed = <String>[];
  if (files.isEmpty) return FolderUploadResult(skipped: skipped, failed: failed);

  final jobIds = <File, String>{
    for (final file in files)
      file: '${DateTime.now().microsecondsSinceEpoch}_${_nameOf(file)}',
  };

  batch.startBatch([
    for (final file in files) (id: jobIds[file]!, fileName: _nameOf(file)),
  ]);

  for (final file in files) {
    final name = _nameOf(file);
    final jobId = jobIds[file]!;
    try {
      await service.uploadFile(
        folderPath,
        file,
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(
              jobId,
              sent / total,
              sentBytes: sent,
              totalBytes: total,
            );
          }
        },
      );
      batch.complete(jobId);
    } on FileAlreadyExistsException {
      debugLogger.info('UPLOAD', 'Skipped, already exists', name);
      skipped.add(name);
      batch.fail(jobId, 'already exists');
    } catch (e) {
      debugLogger.error('UPLOAD', 'Error uploading $name', e.toString());
      failed.add(name);
      batch.fail(jobId, e.toString());
    }
  }

  batch.finishBatch();
  return FolderUploadResult(skipped: skipped, failed: failed);
}

String _nameOf(File file) => file.uri.pathSegments.last;

void showUploadSkippedDialog(BuildContext context, List<String> skipped) {
  showDialog<void>(
    context: context,
    builder: (ctx) => SnDialog(
      title: 'Some files already existed',
      content: Text(
        '${skipped.length} file(s) were skipped because they already exist:\n\n${skipped.join('\n')}',
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontSans,
          fontSize: 13,
          color: SpaceNotesTheme.fg,
        ),
      ),
      actions: [
        SnDialogAction(
          label: 'OK',
          variant: SnButtonVariant.outline,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}
