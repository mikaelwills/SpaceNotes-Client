import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../providers/notes_providers.dart';
import '../providers/middle_pane_mode_provider.dart';
import '../providers/file_transfer_providers.dart';
import '../providers/upload_progress_providers.dart';
import '../services/debug_logger.dart';
import '../services/file_transfer_service.dart';
import '../theme/spacenotes_theme.dart';
import '../file_types/file_type_registry.dart';
import '../widgets/folder_picker_field.dart';
import '../widgets/primitives/primitives.dart';

/// Create/upload actions shared by the sidebar footer (always targets 'All
/// Notes') and the desktop content-area FAB (targets whatever folder is
/// currently open). [targetFolder] is the destination for a new note or the
/// pre-filled default for the upload-target picker.

void ensureNotesView(BuildContext context) {
  final location = GoRouterState.of(context).uri.toString();
  if (location.startsWith('/agents') ||
      location.startsWith('/settings') ||
      location.startsWith('/connect')) {
    context.go('/notes');
  }
}

void openNoteInDesktop(
  BuildContext context,
  WidgetRef ref,
  String noteId, {
  required String parentFolderPath,
}) {
  context
      .read<DesktopNotesBloc>()
      .add(OpenNote(noteId, parentFolderPath: parentFolderPath));
  ref.read(middlePaneModeProvider.notifier).state =
      MiddlePaneMode.fileViewer(noteId);
  ensureNotesView(context);
}

Future<void> createNoteInFolder(
  BuildContext context,
  WidgetRef ref,
  String targetFolder,
) async {
  final repo = ref.read(notesRepositoryProvider);
  final notePath = '$targetFolder/${FileTypeRegistry.defaultNewFileName()}';
  final noteId = await repo.createNote(notePath, '');
  if (noteId != null && context.mounted) {
    openNoteInDesktop(context, ref, noteId, parentFolderPath: targetFolder);
  }
}

Future<void> uploadFilesToFolder(
  BuildContext context,
  WidgetRef ref,
  String targetFolder,
) async {
  final target = await pickUploadTarget(
    context,
    ref,
    currentFolder: targetFolder,
    showFolderOption: true,
  );
  if (target == null || !context.mounted) return;

  final repo = ref.read(notesRepositoryProvider);
  await repo.createFolder(target.folder);
  if (!context.mounted) return;
  final resolvedFolder = target.folder;

  if (target.kind == UploadSourceKind.folder) {
    await _uploadFolder(context, ref, resolvedFolder);
    return;
  }

  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: target.source!,
  );
  if (result == null || result.files.isEmpty) {
    debugLogger.info('UPLOAD', 'File picker cancelled or empty selection');
    return;
  }
  debugLogger.info(
    'UPLOAD',
    'Files selected',
    'count=${result.files.length} folder=$resolvedFolder',
  );

  if (!context.mounted) return;
  final service = ref.read(fileTransferServiceProvider);
  final batch = ref.read(uploadBatchProvider.notifier);
  final uploadable = result.files.where((f) => f.path != null).toList();

  if (uploadable.length == 1) {
    await _uploadSingleWithCollisionDialog(
      context,
      service,
      batch,
      resolvedFolder,
      uploadable.first,
    );
    return;
  }

  final jobIds = {
    for (final picked in uploadable)
      picked: '${DateTime.now().microsecondsSinceEpoch}_${picked.name}',
  };
  batch.startBatch([
    for (final picked in uploadable) (id: jobIds[picked]!, fileName: picked.name)
  ]);

  final skipped = <String>[];
  for (final picked in uploadable) {
    final path = picked.path!;
    final jobId = jobIds[picked]!;
    try {
      await service.uploadFile(
        resolvedFolder,
        File(path),
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(jobId, sent / total, sentBytes: sent, totalBytes: total);
          }
        },
      );
      batch.complete(jobId);
    } on FileAlreadyExistsException {
      skipped.add(picked.name);
      batch.fail(jobId, 'already exists');
    } catch (e) {
      debugLogger.error('UPLOAD', 'Error uploading ${picked.name}', e.toString());
      batch.fail(jobId, e.toString());
    }
  }
  batch.finishBatch();
  if (skipped.isNotEmpty && context.mounted) {
    _showSkippedDialog(context, skipped);
  }
}

Future<void> _uploadSingleWithCollisionDialog(
  BuildContext context,
  FileTransferService service,
  UploadBatchNotifier batch,
  String targetFolder,
  PlatformFile picked,
) async {
  final path = picked.path!;
  final jobId = '${DateTime.now().microsecondsSinceEpoch}_${picked.name}';

  batch.startBatch([(id: jobId, fileName: picked.name)]);
  try {
    await service.uploadFile(
      targetFolder,
      File(path),
      onProgress: (sent, total) {
        if (total > 0) {
          batch.progress(jobId, sent / total, sentBytes: sent, totalBytes: total);
        }
      },
    );
    batch.complete(jobId);
    batch.finishBatch();
  } on FileAlreadyExistsException {
    batch.finishBatch();
    if (!context.mounted) return;
    await _showAlreadyExistsDialog(context, picked.name, targetFolder);
  } catch (e) {
    debugLogger.error('UPLOAD', 'Error uploading ${picked.name}', e.toString());
    batch.fail(jobId, e.toString());
    batch.finishBatch();
  }
}

Future<void> _showAlreadyExistsDialog(
  BuildContext context,
  String fileName,
  String folderName,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => SnDialog(
      title: 'File already exists',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fileName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 15,
              color: SpaceNotesTheme.fg,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'already exists in $folderName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 13,
              color: SpaceNotesTheme.muted,
            ),
          ),
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

Future<void> _uploadFolder(
  BuildContext context,
  WidgetRef ref,
  String targetFolder,
) async {
  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null || !context.mounted) {
    debugLogger.info('UPLOAD', 'Folder picker cancelled');
    return;
  }

  final rootDir = Directory(dirPath);
  final rootName = rootDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
  final entries = rootDir.listSync(recursive: true).whereType<File>().toList();
  debugLogger.info(
    'UPLOAD',
    'Folder selected',
    'root=$rootName files=${entries.length} target=$targetFolder',
  );

  final repo = ref.read(notesRepositoryProvider);
  final service = ref.read(fileTransferServiceProvider);
  final batch = ref.read(uploadBatchProvider.notifier);
  final createdFolders = <String>{};
  final skipped = <String>[];

  final jobIds = {
    for (final file in entries)
      file: '${DateTime.now().microsecondsSinceEpoch}_${file.uri.pathSegments.last}',
  };
  batch.startBatch([
    for (final file in entries)
      (id: jobIds[file]!, fileName: file.uri.pathSegments.last)
  ]);

  for (final file in entries) {
    final relative = file.path.substring(rootDir.path.length + 1);
    final relativeDir =
        relative.contains('/') ? relative.substring(0, relative.lastIndexOf('/')) : '';
    final vaultFolder = relativeDir.isEmpty
        ? '$targetFolder/$rootName'
        : '$targetFolder/$rootName/$relativeDir';

    if (createdFolders.add(vaultFolder)) {
      await repo.createFolder(vaultFolder);
    }

    final jobId = jobIds[file]!;
    try {
      await service.uploadFile(
        vaultFolder,
        file,
        onProgress: (sent, total) {
          if (total > 0) {
            batch.progress(jobId, sent / total, sentBytes: sent, totalBytes: total);
          }
        },
      );
      batch.complete(jobId);
    } on FileAlreadyExistsException {
      skipped.add('$vaultFolder/${file.uri.pathSegments.last}');
      batch.fail(jobId, 'already exists');
    } catch (e) {
      debugLogger.error('UPLOAD', 'Error uploading ${file.path}', e.toString());
      batch.fail(jobId, e.toString());
    }
  }
  batch.finishBatch();

  if (skipped.isNotEmpty && context.mounted) {
    _showSkippedDialog(context, skipped);
  }
}

void _showSkippedDialog(BuildContext context, List<String> skipped) {
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

Future<void> createFolderIn(
  BuildContext context,
  WidgetRef ref,
  String parentFolder,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: SpaceNotesTextStyles.terminal,
        decoration: const InputDecoration(
          hintText: 'Folder name',
        ),
        onSubmitted: (value) => Navigator.of(ctx).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel',
              style: SpaceNotesTextStyles.terminal
                  .copyWith(color: SpaceNotesTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text('Create',
              style: SpaceNotesTextStyles.terminal
                  .copyWith(color: SpaceNotesTheme.primary)),
        ),
      ],
    ),
  );
  if (result == null || result.isEmpty || !context.mounted) return;

  final fullPath = parentFolder.isEmpty ? result : '$parentFolder/$result';
  final folders = ref.read(foldersListProvider);
  final existingFolder = folders.any((f) => f.path == fullPath);
  if (existingFolder) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Folder Exists'),
          content: Text('A folder named "$fullPath" already exists.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK',
                  style: SpaceNotesTextStyles.terminal
                      .copyWith(color: SpaceNotesTheme.primary)),
            ),
          ],
        ),
      );
    }
  } else {
    final repo = ref.read(notesRepositoryProvider);
    await repo.createFolder(fullPath);
  }
}
