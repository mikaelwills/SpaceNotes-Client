import '../generated/space_file.dart';
import '../repositories/spacetimedb_notes_repository.dart';
import 'debug_logger.dart';

/// How a bulk operation went.
///
/// Carries per-file outcomes rather than a single bool: on a batch of thirty,
/// "it failed" is useless — the user needs to know which ones and how many
/// survived.
class BulkResult {
  const BulkResult({required this.succeeded, required this.failed});

  final List<String> succeeded;
  final List<String> failed;

  int get total => succeeded.length + failed.length;
  bool get allSucceeded => failed.isEmpty;
  bool get allFailed => succeeded.isEmpty && failed.isNotEmpty;

  String get summary {
    if (allSucceeded) return '${succeeded.length} of ${succeeded.length}';
    return '${succeeded.length} of $total';
  }
}

/// Deletes many files, one reducer call each.
///
/// There is no batch reducer, so this is a loop — but it must not stop on the
/// first failure, or a single protected or already-deleted file would strand
/// the rest.
Future<BulkResult> deleteFiles(
  SpacetimeDbNotesRepository repository,
  List<SpaceFile> files,
) async {
  final succeeded = <String>[];
  final failed = <String>[];

  for (final file in files) {
    try {
      final ok = await repository.deleteNote(file.id);
      (ok ? succeeded : failed).add(file.name);
    } catch (e) {
      debugLogger.error('BULK', 'Delete failed: ${file.name}', e.toString());
      failed.add(file.name);
    }
  }

  debugLogger.info('BULK', 'Bulk delete finished',
      'ok=${succeeded.length} failed=${failed.length}');
  return BulkResult(succeeded: succeeded, failed: failed);
}

/// Moves many files into [targetFolderPath].
///
/// A file already in the target is counted as succeeded rather than moved:
/// asking the server to move something onto itself is a needless failure.
Future<BulkResult> moveFiles(
  SpacetimeDbNotesRepository repository,
  List<SpaceFile> files,
  String targetFolderPath,
) async {
  final succeeded = <String>[];
  final failed = <String>[];
  final prefix = targetFolderPath.isEmpty ? '' : '$targetFolderPath/';

  for (final file in files) {
    if (file.folderPath == prefix) {
      succeeded.add(file.name);
      continue;
    }

    try {
      final ok = await repository.moveNote(file.path, '$prefix${file.name}');
      (ok ? succeeded : failed).add(file.name);
    } catch (e) {
      debugLogger.error('BULK', 'Move failed: ${file.name}', e.toString());
      failed.add(file.name);
    }
  }

  debugLogger.info('BULK', 'Bulk move finished',
      'to=$targetFolderPath ok=${succeeded.length} failed=${failed.length}');
  return BulkResult(succeeded: succeeded, failed: failed);
}
