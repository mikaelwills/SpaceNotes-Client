import 'dart:io';

import 'package:flutter/material.dart';

import '../file_types/file_type_registry.dart';
import '../providers/upload_progress_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/sn_button.dart';
import '../widgets/primitives/sn_dialog.dart';
import 'debug_logger.dart';
import 'file_transfer_service.dart';

class FolderUploadResult {
  const FolderUploadResult({
    required this.skipped,
    required this.failed,
    this.unsupported = const [],
  });

  final List<String> skipped;
  final List<String> failed;
  final List<String> unsupported;

  bool get hasSkipped => skipped.isNotEmpty;
  bool get hasFailed => failed.isNotEmpty;
  bool get hasUnsupported => unsupported.isNotEmpty;
}

class UploadPartition {
  const UploadPartition({required this.supported, required this.unsupported});

  final List<File> supported;
  final List<String> unsupported;
}

UploadPartition partitionUploads(List<File> files) {
  final supported = <File>[];
  final unsupported = <String>[];
  for (final file in files) {
    final name = _nameOf(file);
    if (FileTypeRegistry.isHiddenName(name)) {
      debugLogger.info('UPLOAD', 'Skipped hidden file', name);
      continue;
    }
    if (FileTypeRegistry.isUploadable(name)) {
      supported.add(file);
    } else {
      debugLogger.info('UPLOAD', 'Unsupported file type', name);
      unsupported.add(name);
    }
  }
  return UploadPartition(supported: supported, unsupported: unsupported);
}

Future<FolderUploadResult> uploadFilesToFolder({
  required FileTransferService service,
  required UploadBatchNotifier batch,
  required String folderPath,
  required List<File> files,
}) async {
  final skipped = <String>[];
  final failed = <String>[];
  final partition = partitionUploads(files);
  final supported = partition.supported;
  if (supported.isEmpty) {
    return FolderUploadResult(
      skipped: skipped,
      failed: failed,
      unsupported: partition.unsupported,
    );
  }

  final jobIds = <File, String>{
    for (final file in supported)
      file: '${DateTime.now().microsecondsSinceEpoch}_${_nameOf(file)}',
  };

  batch.startBatch([
    for (final file in supported)
      (id: jobIds[file]!, fileName: _nameOf(file)),
  ]);

  for (final file in supported) {
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
  return FolderUploadResult(
    skipped: skipped,
    failed: failed,
    unsupported: partition.unsupported,
  );
}

String _nameOf(File file) => file.uri.pathSegments.last;

Future<void> showUploadOutcomeDialogs(
  BuildContext context,
  FolderUploadResult result,
) async {
  if (result.hasFailed) {
    await showUploadFailedDialog(context, result.failed);
  } else if (result.hasSkipped) {
    await showUploadSkippedDialog(context, result.skipped);
  }
  if (!context.mounted) return;
  if (result.hasUnsupported) {
    await showUnsupportedFilesDialog(context, result.unsupported);
  }
}

Future<void> showUploadSkippedDialog(
  BuildContext context,
  List<String> skipped,
) {
  return _showListDialog(
    context,
    title: 'Some files already existed',
    lead: '${skipped.length} file(s) were skipped because they already exist:',
    names: skipped,
  );
}

Future<void> showUploadFailedDialog(
  BuildContext context,
  List<String> failed,
) {
  return _showListDialog(
    context,
    title: 'Some files failed to upload',
    lead: '${failed.length} file(s) could not be uploaded:',
    names: failed,
  );
}

Future<void> showUnsupportedFilesDialog(
  BuildContext context,
  List<String> unsupported,
) {
  final one = unsupported.length == 1;
  return _showListDialog(
    context,
    title: one ? 'Unsupported file type' : 'Unsupported file types',
    lead: one
        ? 'SpaceNotes cannot store this file type yet:'
        : 'SpaceNotes cannot store these file types yet:',
    names: unsupported,
    footer: 'Supported: ${FileTypeRegistry.uploadableExtensions.join(', ')}',
  );
}

Future<void> _showListDialog(
  BuildContext context, {
  required String title,
  required String lead,
  required List<String> names,
  String? footer,
}) {
  const body = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 13,
    color: SpaceNotesTheme.fg,
  );
  const dim = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 12,
    color: SpaceNotesTheme.muted,
  );
  return showDialog<void>(
    context: context,
    builder: (ctx) => SnDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$lead\n\n${names.join('\n')}', style: body),
          if (footer != null) ...[
            const SizedBox(height: 12),
            Text(footer, style: dim),
          ],
        ],
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
