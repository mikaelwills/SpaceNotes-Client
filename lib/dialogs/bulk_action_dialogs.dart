import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_providers.dart';
import '../services/bulk_file_actions.dart';
import '../theme/spacenotes_theme.dart';

/// Confirmation and reporting for actions that hit many files at once.
class BulkActionDialogs {
  /// Names the first few items rather than only counting them: "delete 24
  /// items" is easy to confirm without noticing the wrong batch is ticked.
  ///
  /// [names] is every selected file/folder's display name, in selection
  /// order; folder names get no special marking here since the dialog can't
  /// show a per-item icon, only the count/preview.
  static Future<bool> confirmDelete(
    BuildContext context,
    List<String> names,
  ) async {
    const preview = 5;
    final previewNames = names.take(preview).join('\n');
    final rest = names.length - preview;

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
          'Delete ${names.length} ${names.length == 1 ? 'item' : 'items'}?',
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          rest > 0 ? '$previewNames\n…and $rest more' : previewNames,
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
    int itemCount,
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
          'Move $itemCount ${itemCount == 1 ? 'item' : 'items'} to',
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

  /// Says what happened. A partial failure names the items that did not make
  /// it, since those are the ones needing another go.
  static void reportResult(
    BuildContext context,
    String verb,
    BulkResult result,
  ) {
    final message = result.allSucceeded
        ? '$verb ${result.succeeded.length} ${result.succeeded.length == 1 ? 'item' : 'items'}'
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
