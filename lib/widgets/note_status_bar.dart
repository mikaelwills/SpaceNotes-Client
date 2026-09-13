import 'package:flutter/material.dart';

import '../file_types/file_type_registry.dart';
import '../generated/space_file.dart';
import '../theme/spacenotes_theme.dart';
import 'editable_name.dart';
import 'primitives/primitives.dart';

class NoteStatusBar extends StatelessWidget {
  const NoteStatusBar({
    super.key,
    required this.note,
    this.contentHydrated = false,
  });

  final SpaceFile note;

  /// Shows the fresh-content mark: the server's current body has arrived.
  /// A note painted from cache opens without it until the live row lands.
  final bool contentHydrated;

  @override
  Widget build(BuildContext context) {
    final fileType = FileTypeRegistry.forFile(note);
    final displayName = fileType.stripExtension(note.name);
    final folder = note.folderPath;

    return SnStatusLine(
      trailing: contentHydrated
          ? const Icon(
              Icons.cloud_done_outlined,
              size: 12,
              color: SpaceNotesTheme.online,
            )
          : null,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fileType.icon, size: 12, color: fileType.color),
          const SizedBox(width: 8),
          Flexible(
            child: EditableNoteName(
              notePath: note.path,
              currentName: displayName,
              isRenameable: fileType.isRenameable,
            ),
          ),
          if (folder.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                folder,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
