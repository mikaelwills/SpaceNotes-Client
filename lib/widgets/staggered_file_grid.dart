import 'package:flutter/material.dart';
import '../generated/space_file.dart';
import 'file_grid_card.dart';

/// Two-column staggered grid of file cards. Shared by the recent-notes home
/// page and folder browsing, so both render every file type the same way.
class StaggeredFileGrid extends StatelessWidget {
  const StaggeredFileGrid({
    super.key,
    required this.files,
    required this.onTap,
    this.onLongPress,
  });

  final List<SpaceFile> files;
  final void Function(SpaceFile file) onTap;
  final void Function(SpaceFile file)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final leftColumn = <_IndexedFile>[];
    final rightColumn = <_IndexedFile>[];

    for (int i = 0; i < files.length; i++) {
      final indexed = _IndexedFile(file: files[i], index: i + 1);
      if (i % 2 == 0) {
        leftColumn.add(indexed);
      } else {
        rightColumn.add(indexed);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const columnGap = 10.0;
        final columnWidth = (constraints.maxWidth - columnGap) / 2;

        Widget buildCard(_IndexedFile f) => FileGridCard(
              file: f.file,
              index: f.index,
              onTap: () => onTap(f.file),
              onLongPress:
                  onLongPress == null ? null : () => onLongPress!(f.file),
            );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: columnWidth,
              child: Column(children: leftColumn.map(buildCard).toList()),
            ),
            const SizedBox(width: columnGap),
            SizedBox(
              width: columnWidth,
              child: Column(children: rightColumn.map(buildCard).toList()),
            ),
          ],
        );
      },
    );
  }
}

class _IndexedFile {
  final SpaceFile file;
  final int index;
  _IndexedFile({required this.file, required this.index});
}
