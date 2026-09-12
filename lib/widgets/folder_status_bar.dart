import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/file_sort_provider.dart';
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
      trailing: trailing ?? const FileSortToggle(),
    );
  }
}

class FileSortToggle extends ConsumerWidget {
  const FileSortToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(fileSortModeProvider);
    final byName = mode == FileSortMode.name;

    return GestureDetector(
      key: const ValueKey('sort-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(fileSortModeProvider.notifier).toggle(),
      child: Tooltip(
        message: byName ? 'Sorted by name' : 'Sorted by date modified',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(
            byName ? Icons.sort_by_alpha : Icons.schedule,
            size: 13,
            color: SpaceNotesTheme.dim,
          ),
        ),
      ),
    );
  }
}
