import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/note.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';

class RecentNotesGrid extends ConsumerWidget {
  static const double maxCardHeight = 100.0;

  const RecentNotesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    final recentNotesAsync = ref.watch(recentNotesProvider);

    return recentNotesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (notes) {
        if (notes.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildStaggeredGrid(context, notes),
        );
      },
    );
  }

  Widget _buildStaggeredGrid(BuildContext context, List<Note> notes) {
    final leftColumn = <Note>[];
    final rightColumn = <Note>[];

    for (int i = 0; i < notes.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(notes[i]);
      } else {
        rightColumn.add(notes[i]);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const columnGap = 8.0;
        final columnWidth = (constraints.maxWidth - columnGap) / 2;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: columnWidth,
              child: Column(
                children: leftColumn
                    .map((note) => _buildRecentNoteCard(context, note))
                    .toList(),
              ),
            ),
            const SizedBox(width: columnGap),
            SizedBox(
              width: columnWidth,
              child: Column(
                children: rightColumn
                    .map((note) => _buildRecentNoteCard(context, note))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentNoteCard(BuildContext context, Note note) {
    return GestureDetector(
      onTap: () {
        final encodedPath =
            note.path.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedPath');
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: maxCardHeight),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              note.name,
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: SpaceNotesTheme.text,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                note.content,
                style: const TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 12,
                  color: SpaceNotesTheme.textSecondary,
                  height: 1.4,
                ),
                overflow: TextOverflow.clip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
