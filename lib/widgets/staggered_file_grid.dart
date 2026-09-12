import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../generated/space_file.dart';
import 'file_grid_card.dart';

/// Lazy masonry grid of file cards, as a sliver. Shared by the recent-notes
/// home page and folder browsing, so both render every file type the same
/// way. Cards keep their natural (variable) height, but only cards in or
/// near the viewport are ever built, laid out, or painted — a wide search
/// match set stays cheap regardless of how many notes match.
class StaggeredFileGrid extends StatelessWidget {
  const StaggeredFileGrid({
    super.key,
    required this.files,
    required this.onTap,
    this.onLongPress,
    this.selectedIds = const {},
  });

  final List<SpaceFile> files;
  final void Function(SpaceFile file) onTap;
  final void Function(SpaceFile file)? onLongPress;
  final Set<String> selectedIds;

  static const _targetCardWidth = 180.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.extent(
      maxCrossAxisExtent: _targetCardWidth,
      mainAxisSpacing: _gap,
      crossAxisSpacing: _gap,
      childCount: files.length,
      itemBuilder: (context, i) => FileGridCard(
        key: ValueKey(files[i].path),
        file: files[i],
        index: i + 1,
        onTap: () => onTap(files[i]),
        onLongPress: onLongPress == null ? null : () => onLongPress!(files[i]),
        selected: selectedIds.contains(files[i].id),
      ),
    );
  }
}
