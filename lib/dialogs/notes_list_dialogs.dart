import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/space_file.dart';
import '../generated/folder.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../file_types/file_type_registry.dart';
import '../widgets/folder_destination_list.dart';

/// Static dialog functions for TopFolderListScreen
class NotesListDialogs {
  /// Show context menu for a note with move and delete options
  static void showNoteContextMenu(
    BuildContext context,
    WidgetRef ref,
    SpaceFile note, {
    String? navigateToAfterDelete,
  }) {
    showDialog(
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
          note.name,
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (FileTypeRegistry.forFile(note).isMovable)
              ListTile(
                key: const ValueKey('dialog-move'),
                leading: const Icon(
                  Icons.drive_file_move_outline,
                  color: SpaceNotesTheme.primary,
                ),
                title: const Text(
                  'Move to folder',
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  showMoveNoteDialog(context, ref, note);
                },
              ),
            if (FileTypeRegistry.forFile(note).isOffloadable)
              Consumer(
                builder: (context, dialogRef, _) {
                  final state = dialogRef
                      .watch(downloadStateProvider(note.path))
                      .valueOrNull;
                  if (state != DownloadState.complete) {
                    return const SizedBox.shrink();
                  }
                  return ListTile(
                    key: const ValueKey('dialog-offload'),
                    leading: const Icon(
                      Icons.cloud_off_outlined,
                      color: SpaceNotesTheme.primary,
                    ),
                    title: const Text(
                      'Offload file',
                      style: TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.text,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      await dialogRef
                          .read(localDownloadStoreProvider)
                          .offload(note.path);
                      dialogRef.invalidate(downloadStateProvider(note.path));
                    },
                  );
                },
              ),
            if (FileTypeRegistry.forFile(note).isDeletable)
              ListTile(
                key: const ValueKey('dialog-delete'),
                leading: const Icon(
                  Icons.delete_outline,
                  color: SpaceNotesTheme.error,
                ),
                title: const Text(
                  'Delete note',
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  showDeleteNoteConfirmation(
                    context,
                    ref,
                    note,
                    navigateToAfterDelete: navigateToAfterDelete,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show context menu for a folder with move and delete options
  static void showFolderContextMenu(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    if (FileTypeRegistry.isProtectedPath(folder.path)) return;
    showDialog(
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
          folder.name,
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('dialog-rename'),
              leading: const Icon(
                Icons.edit_outlined,
                color: SpaceNotesTheme.primary,
              ),
              title: const Text(
                'Rename',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: SpaceNotesTheme.text,
                ),
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                showRenameFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              key: const ValueKey('dialog-move'),
              leading: const Icon(
                Icons.drive_file_move_outline,
                color: SpaceNotesTheme.primary,
              ),
              title: const Text(
                'Move to folder',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: SpaceNotesTheme.text,
                ),
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                showMoveFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              key: const ValueKey('dialog-delete'),
              leading: const Icon(
                Icons.delete_outline,
                color: SpaceNotesTheme.error,
              ),
              title: const Text(
                'Delete folder',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: SpaceNotesTheme.error,
                ),
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                showDeleteFolderConfirmation(context, ref, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to create a new folder
  static void showCreateFolderDialog(
    BuildContext context,
    WidgetRef ref, {
    String currentPath = '', // Empty string = root/top level
  }) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
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
        title: const Text(
          'Create New Folder',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 400,
          ),
          child: Form(
            key: formKey,
            child: Container(
              height: 52,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: SpaceNotesTheme.primary,
                    width: 2,
                  ),
                  right: BorderSide(
                    color: SpaceNotesTheme.primary,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    '❯',
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: SpaceNotesTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() ?? false) {
                          final folderName = nameController.text.trim();
                          Navigator.of(dialogContext).pop();

                          // Build full folder path based on current path
                          final String fullFolderPath;
                          if (currentPath.isEmpty) {
                            // At root: create top-level folder
                            fullFolderPath = folderName;
                          } else {
                            // Inside a folder: create subfolder
                            final normalizedPath = currentPath.endsWith('/')
                                ? currentPath.substring(
                                    0, currentPath.length - 1)
                                : currentPath;
                            fullFolderPath = '$normalizedPath/$folderName';
                          }

                          ref
                              .read(notesRepositoryProvider)
                              .createFolder(fullFolderPath);
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.text,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: 'Folder name',
                        hintStyle:
                            TextStyle(color: SpaceNotesTheme.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Folder name is required';
                        }
                        // Check for invalid characters
                        if (value.contains(RegExp(r'[<>:"/\|?*]'))) {
                          return 'Invalid characters in folder name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('dialog-cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SpaceNotesTheme.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('dialog-confirm'),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        final folderName = nameController.text.trim();
                        Navigator.of(dialogContext).pop();

                        // Build full folder path based on current path
                        final String fullFolderPath;
                        if (currentPath.isEmpty) {
                          // At root: create top-level folder
                          fullFolderPath = folderName;
                        } else {
                          // Inside a folder: create subfolder
                          final normalizedPath = currentPath.endsWith('/')
                              ? currentPath.substring(0, currentPath.length - 1)
                              : currentPath;
                          fullFolderPath = '$normalizedPath/$folderName';
                        }

                        ref
                            .read(notesRepositoryProvider)
                            .createFolder(fullFolderPath);
                      }
                    },
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog before deleting a note
  static void showDeleteNoteConfirmation(
    BuildContext context,
    WidgetRef ref,
    SpaceFile note, {
    String? navigateToAfterDelete,
  }) {
    if (!FileTypeRegistry.forFile(note).isDeletable) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpaceNotesTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: SpaceNotesTheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Note',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${note.name}"?\n\nThis action cannot be undone.',
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: SpaceNotesTheme.text,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: SpaceNotesTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('dialog-confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();

              print('🗑️  DELETE: Deleting note ${note.path}');
              print(
                  '🗑️  DELETE: navigateToAfterDelete = $navigateToAfterDelete');

              if (!FileTypeRegistry.forFile(note).isDeletable) return;
              ref.read(notesRepositoryProvider).deleteNote(note.id);

              // Navigate to specified location after delete
              if (navigateToAfterDelete != null && context.mounted) {
                print('🗑️  DELETE: Navigating to $navigateToAfterDelete');
                context.go(navigateToAfterDelete);
              } else {
                print('🗑️  DELETE: No navigation (staying on current screen)');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: SpaceNotesTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog before deleting a folder
  static void showDeleteFolderConfirmation(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    if (FileTypeRegistry.isProtectedPath(folder.path)) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpaceNotesTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: SpaceNotesTheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Folder',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${folder.name}"?\n\nThis will delete all notes and subfolders inside. This action cannot be undone.',
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: SpaceNotesTheme.text,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: SpaceNotesTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('dialog-confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(notesRepositoryProvider).deleteFolder(folder.path);
            },
            style: TextButton.styleFrom(
              foregroundColor: SpaceNotesTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to select a folder to move a note to
  static void showMoveNoteDialog(
    BuildContext context,
    WidgetRef ref,
    SpaceFile note,
  ) {
    if (!FileTypeRegistry.forFile(note).isMovable) return;
    final folders = ref.read(foldersListProvider);

    () {
      // `pass` stores every credential as a real directory, so the credential
      // store contributes hundreds of folder rows that are never a destination
      // for a note.
      final sortedFolders = folders
          .where((f) => !FileTypeRegistry.isProtectedPath(f.path))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (sortedFolders.isEmpty) {
        // No folders available, show error
        showDialog(
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
            title: const Text(
              'No Folders',
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 16,
                color: SpaceNotesTheme.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: const Text(
              'Create a folder first before moving notes.',
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: SpaceNotesTheme.text,
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('dialog-ok'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show folder selection dialog
      showDialog(
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
            'Move "${note.name}" to folder',
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: FolderDestinationList(
            destinations: [
              for (final folder in sortedFolders)
                FolderDestination(
                  path: folder.path,
                  label: folder.name,
                  isCurrent: note.folderPath == '${folder.path}/',
                  currentLabel: 'Current folder',
                  onTap: () async {
                          Navigator.of(dialogContext).pop();

                          // Calculate new path: folder.path + note filename
                          final fileName = note.path.split('/').last;
                          final newPath = '${folder.path}/$fileName';

                          debugLogger.info('MOVE', 'Moving note',
                              '${note.path} -> $newPath');

                          final success = await ref
                              .read(notesRepositoryProvider)
                              .renameNote(note.id, newPath);

                          if (!success && context.mounted) {
                            // Show error if move failed
                            showDialog(
                              context: context,
                              builder: (errorContext) => AlertDialog(
                                backgroundColor: SpaceNotesTheme.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                  side: BorderSide(
                                    color: SpaceNotesTheme.error
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                title: const Text(
                                  'Move Failed',
                                  style: TextStyle(
                                    fontFamily: 'FiraCode',
                                    fontSize: 16,
                                    color: SpaceNotesTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                content: const Text(
                                  'Failed to move note. Please try again.',
                                  style: TextStyle(
                                    fontFamily: 'FiraCode',
                                    fontSize: 14,
                                    color: SpaceNotesTheme.text,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    key: const ValueKey('dialog-ok'),
                                    onPressed: () =>
                                        Navigator.of(errorContext).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        ),
      );
    }();
  }

  /// Show dialog to select a destination folder to move a folder to
  static void showMoveFolderDialog(
    BuildContext context,
    WidgetRef ref,
    Folder folderToMove,
  ) {
    if (FileTypeRegistry.isProtectedPath(folderToMove.path)) return;
    final folders = ref.read(foldersListProvider);

    () {
      // Filter out the folder being moved and its subfolders, then sort alphabetically
      final availableFolders = folders.where((folder) {
        // Can't move a folder into itself
        if (folder.path == folderToMove.path) return false;

        // Can't move a folder into its own subfolder
        if (folder.path.startsWith('${folderToMove.path}/')) return false;

        // `pass` stores every credential as a real directory, so the credential
        // store contributes hundreds of folder rows that are never a destination.
        if (FileTypeRegistry.isProtectedPath(folder.path)) return false;

        return true;
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Show folder selection dialog
      showDialog(
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
            'Move "${folderToMove.name}"',
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 16,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: FolderDestinationList(
            destinations: [
              FolderDestination(
                path: 'Top Level',
                label: 'Top Level',
                icon: Icons.home_outlined,
                currentIcon: Icons.home,
                isCurrent: folderToMove.depth == 0,
                currentLabel: 'Already at top level',
                onTap: () async {
                            Navigator.of(dialogContext).pop();

                            // Move to top level (just the folder name)
                            final newPath = folderToMove.name;

                            debugLogger.info('MOVE', 'Moving folder to top level',
                                '${folderToMove.path} -> $newPath');

                            final success = await ref
                                .read(notesRepositoryProvider)
                                .moveFolder(
                                  folderToMove.path,
                                  newPath,
                                );

                            if (!success && context.mounted) {
                              // Show error if move failed
                              showDialog(
                                context: context,
                                builder: (errorContext) => AlertDialog(
                                  backgroundColor: SpaceNotesTheme.background,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                    side: BorderSide(
                                      color: SpaceNotesTheme.error
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  title: const Text(
                                    'Move Failed',
                                    style: TextStyle(
                                      fontFamily: 'FiraCode',
                                      fontSize: 16,
                                      color: SpaceNotesTheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  content: const Text(
                                    'Failed to move folder. Please try again.',
                                    style: TextStyle(
                                      fontFamily: 'FiraCode',
                                      fontSize: 14,
                                      color: SpaceNotesTheme.text,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      key: const ValueKey('dialog-ok'),
                                      onPressed: () =>
                                          Navigator.of(errorContext).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
              ),
              for (final folder in availableFolders)
                FolderDestination(
                  path: folder.path,
                  label: folder.name,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();

                    // Calculate new path: destinationFolder.path + folderToMove.name
                    final newPath = '${folder.path}/${folderToMove.name}';

                    debugLogger.info('MOVE', 'Moving folder',
                        '${folderToMove.path} -> $newPath');

                    final success =
                        await ref.read(notesRepositoryProvider).moveFolder(
                              folderToMove.path,
                              newPath,
                            );

                    if (!success && context.mounted) {
                      // Show error if move failed
                      showDialog(
                        context: context,
                        builder: (errorContext) => AlertDialog(
                          backgroundColor: SpaceNotesTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(
                              color:
                                  SpaceNotesTheme.error.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          title: const Text(
                            'Move Failed',
                            style: TextStyle(
                              fontFamily: 'FiraCode',
                              fontSize: 16,
                              color: SpaceNotesTheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          content: const Text(
                            'Failed to move folder. Please try again.',
                            style: TextStyle(
                              fontFamily: 'FiraCode',
                              fontSize: 14,
                              color: SpaceNotesTheme.text,
                            ),
                          ),
                          actions: [
                            TextButton(
                              key: const ValueKey('dialog-ok'),
                              onPressed: () => Navigator.of(errorContext).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        ),
      );
    }();
  }

  /// Show dialog to rename a folder
  static void showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    final nameController = TextEditingController(text: folder.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
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
        title: const Text(
          'Rename Folder',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: SpaceNotesTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 400,
          ),
          child: Form(
            key: formKey,
            child: Container(
              height: 52,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: SpaceNotesTheme.primary,
                    width: 2,
                  ),
                  right: BorderSide(
                    color: SpaceNotesTheme.primary,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    '❯',
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: SpaceNotesTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() ?? false) {
                          final newName = nameController.text.trim();
                          Navigator.of(dialogContext).pop();

                          // Build new folder path
                          final parentPath = folder.path.contains('/')
                              ? folder.path.substring(
                                  0, folder.path.lastIndexOf('/') + 1)
                              : '';
                          final newPath = '$parentPath$newName';

                          ref
                              .read(notesRepositoryProvider)
                              .moveFolder(folder.path, newPath);
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.text,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: 'Folder name',
                        hintStyle:
                            TextStyle(color: SpaceNotesTheme.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Folder name is required';
                        }
                        // Check for invalid characters
                        if (value.contains(RegExp(r'[<>:"/\|?*]'))) {
                          return 'Invalid characters in folder name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('dialog-cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SpaceNotesTheme.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('dialog-confirm'),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        final newName = nameController.text.trim();
                        Navigator.of(dialogContext).pop();

                        // Build new folder path
                        final parentPath = folder.path.contains('/')
                            ? folder.path
                                .substring(0, folder.path.lastIndexOf('/') + 1)
                            : '';
                        final newPath = '$parentPath$newName';

                        ref
                            .read(notesRepositoryProvider)
                            .moveFolder(folder.path, newPath);
                      }
                    },
                    child: const Text('Rename'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
