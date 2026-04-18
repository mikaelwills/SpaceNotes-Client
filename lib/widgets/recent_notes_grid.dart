import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/note.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import 'keyboard_dismiss_on_scroll.dart';

class RecentNotesGrid extends ConsumerWidget {
  static const double maxCardHeight = 140.0;

  const RecentNotesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(recentNotesProvider);
    if (notes.isEmpty) {
      return _buildEmptyState();
    }
    return _buildNotesGrid(context, ref, notes);
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 48,
            color: SpaceNotesTheme.dim,
          ),
          SizedBox(height: 20),
          Text(
            'no recent notes',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 12,
              color: SpaceNotesTheme.muted,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'swipe right to browse folders',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.dim,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(
      BuildContext context, WidgetRef ref, List<Note> notes) {
    return KeyboardDismissOnScroll(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
            sliver: SliverToBoxAdapter(
              child: _buildStaggeredGrid(context, ref, notes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredGrid(
      BuildContext context, WidgetRef ref, List<Note> notes) {
    final leftColumn = <_IndexedNote>[];
    final rightColumn = <_IndexedNote>[];

    for (int i = 0; i < notes.length; i++) {
      final indexed = _IndexedNote(note: notes[i], index: i + 1);
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: columnWidth,
              child: Column(
                children: leftColumn
                    .map((n) =>
                        _buildRecentNoteCard(context, ref, n.note, n.index))
                    .toList(),
              ),
            ),
            const SizedBox(width: columnGap),
            SizedBox(
              width: columnWidth,
              child: Column(
                children: rightColumn
                    .map((n) =>
                        _buildRecentNoteCard(context, ref, n.note, n.index))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentNoteCard(
      BuildContext context, WidgetRef ref, Note note, int index) {
    final preview = note.content.trim();
    final hasPreview = preview.isNotEmpty;

    return GestureDetector(
      onTap: () => context.go('/notes/note/${note.id}'),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        NotesListDialogs.showNoteContextMenu(context, ref, note);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
        constraints: const BoxConstraints(maxHeight: maxCardHeight),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.card,
          border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              index.toString().padLeft(3, '0'),
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 9,
                color: SpaceNotesTheme.dim,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note.name,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasPreview) ...[
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  preview,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontSans,
                    fontSize: 12,
                    color: SpaceNotesTheme.muted,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndexedNote {
  final Note note;
  final int index;
  _IndexedNote({required this.note, required this.index});
}
