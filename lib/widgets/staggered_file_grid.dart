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

  static const _targetCardWidth = 180.0;
  static const _columnGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final indexed = [
      for (int i = 0; i < files.length; i++)
        _IndexedFile(file: files[i], index: i + 1),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = ((constraints.maxWidth + _columnGap) /
                (_targetCardWidth + _columnGap))
            .floor()
            .clamp(2, 6);
        final columnWidth =
            (constraints.maxWidth - _columnGap * (columnCount - 1)) /
                columnCount;

        final columns = List.generate(columnCount, (_) => <_IndexedFile>[]);
        for (int i = 0; i < indexed.length; i++) {
          columns[i % columnCount].add(indexed[i]);
        }

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
            for (int c = 0; c < columnCount; c++) ...[
              if (c > 0) const SizedBox(width: _columnGap),
              SizedBox(
                width: columnWidth,
                child: Column(children: columns[c].map(buildCard).toList()),
              ),
            ],
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
