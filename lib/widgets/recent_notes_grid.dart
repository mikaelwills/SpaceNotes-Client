import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/note.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../dialogs/notes_list_dialogs.dart';

class RecentNotesGrid extends ConsumerWidget {
  static const double maxCardHeight = 100.0;

  const RecentNotesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentNotesAsync = ref.watch(recentNotesProvider);

    return recentNotesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(SpaceNotesTheme.primary),
        ),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load recent notes',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: SpaceNotesTheme.textSecondary,
          ),
        ),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          return _buildEmptyState();
        }
        return _buildNotesGrid(context, ref, notes);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 64,
            color: SpaceNotesTheme.textSecondary,
          ),
          SizedBox(height: 24),
          Text(
            'No recent notes',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 18,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Swipe right to browse folders',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(BuildContext context, WidgetRef ref, List<Note> notes) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Folders',
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 12,
                    color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverToBoxAdapter(
            child: _buildStaggeredGrid(context, ref, notes),
          ),
        ),
      ],
    );
  }

  Widget _buildStaggeredGrid(BuildContext context, WidgetRef ref, List<Note> notes) {
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
                    .map((note) => _buildRecentNoteCard(context, ref, note))
                    .toList(),
              ),
            ),
            const SizedBox(width: columnGap),
            SizedBox(
              width: columnWidth,
              child: Column(
                children: rightColumn
                    .map((note) => _buildRecentNoteCard(context, ref, note))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentNoteCard(BuildContext context, WidgetRef ref, Note note) {
    return GestureDetector(
      onTap: () {
        final encodedPath =
            note.path.split('/').map(Uri.encodeComponent).join('/');
        context.go('/notes/note/$encodedPath');
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        NotesListDialogs.showNoteContextMenu(context, ref, note);
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
              color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.1)),
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
