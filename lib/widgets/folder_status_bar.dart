import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';
import 'editable_name.dart';
import 'primitives/primitives.dart';

class FolderStatusBar extends StatelessWidget {
  const FolderStatusBar({
    super.key,
    required this.folderPath,
    this.trailing,
  });

  final String folderPath;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final name = folderPath.split('/').last;
    final parent = folderPath.contains('/')
        ? folderPath.substring(0, folderPath.lastIndexOf('/'))
        : '';

    return SnStatusLine(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_outlined,
            size: 12,
            color: SpaceNotesTheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: EditableFolderName(
              folderPath: folderPath,
              currentName: name,
            ),
          ),
          if (parent.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                parent,
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
      trailing: trailing,
    );
  }
}
