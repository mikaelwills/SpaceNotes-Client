import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../dialogs/notes_list_dialogs.dart';
import 'keyboard_dismiss_on_scroll.dart';
import 'staggered_file_grid.dart';

class RecentNotesGrid extends ConsumerWidget {
  const RecentNotesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(recentFilesProvider);
    if (notes.isEmpty) {
      return _buildEmptyState();
    }
    return KeyboardDismissOnScroll(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
            sliver: SliverToBoxAdapter(
              child: StaggeredFileGrid(
                files: notes,
                onTap: (file) => context.go('/notes/note/${file.id}'),
                onLongPress: (file) =>
                    NotesListDialogs.showNoteContextMenu(context, ref, file),
              ),
            ),
          ),
        ],
      ),
    );
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
}
