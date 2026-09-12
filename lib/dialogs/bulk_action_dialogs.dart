import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../services/bulk_file_actions.dart';
import '../theme/spacenotes_theme.dart';

/// Confirmation and reporting for actions that hit many files at once.
class BulkActionDialogs {
  /// Names the first few files rather than only counting them: "delete 24
  /// files" is easy to confirm without noticing the wrong batch is ticked.
  static Future<bool> confirmDelete(
    BuildContext context,
    List<SpaceFile> files,
  ) async {
    const preview = 5;
    final names = files.take(preview).map((f) => f.name).join('\n');
    final rest = files.length - preview;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpaceNotesTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: SpaceNotesTheme.error.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        title: Text(
          'Delete ${files.length} ${files.length == 1 ? 'file' : 'files'}?',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          rest > 0 ? '$names\n…and $rest more' : names,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 12,
            color: SpaceNotesTheme.dim,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('bulk-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                color: SpaceNotesTheme.dim,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('bulk-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                color: SpaceNotesTheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Returns the chosen folder path, or null if dismissed. An empty string is
  /// a real answer meaning the vault root.
  static Future<String?> pickFolder(
    BuildContext context,
    WidgetRef ref,
    int fileCount,
  ) {
    final folders = ref.read(foldersListProvider).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpaceNotesTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: SpaceNotesTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Text(
          'Move $fileCount ${fileCount == 1 ? 'file' : 'files'} to',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, i) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.folder_outlined,
                size: 16,
                color: SpaceNotesTheme.primary,
              ),
              title: Text(
                folders[i].name,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 13,
                  color: SpaceNotesTheme.text,
                ),
              ),
              onTap: () => Navigator.of(dialogContext).pop(folders[i].path),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('bulk-move-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                color: SpaceNotesTheme.dim,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Says what happened. A partial failure names the files that did not make
  /// it, since those are the ones needing another go.
  static void reportResult(
    BuildContext context,
    String verb,
    BulkResult result,
  ) {
    final message = result.allSucceeded
        ? '$verb ${result.succeeded.length} ${result.succeeded.length == 1 ? 'file' : 'files'}'
        : '$verb ${result.summary} — failed: ${result.failed.join(', ')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 12,
          ),
        ),
        backgroundColor:
            result.allSucceeded ? SpaceNotesTheme.card : SpaceNotesTheme.error,
        duration: Duration(seconds: result.allSucceeded ? 2 : 5),
      ),
    );
  }
}
