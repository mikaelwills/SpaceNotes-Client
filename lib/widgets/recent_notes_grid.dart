import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/space_file.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../providers/recently_viewed_provider.dart';
import '../dialogs/notes_list_dialogs.dart';
import 'keyboard_dismiss_on_scroll.dart';
import 'staggered_file_grid.dart';

/// Two answers to two different questions.
///
/// "Recently Viewed" is what this device has looked at, tracked locally.
/// "Recently Updated" is what changed in the vault, derived from the rows.
/// A file can honestly appear in both — editing it is both a view and a
/// change — so neither section filters the other.
class RecentNotesGrid extends ConsumerWidget {
  const RecentNotesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewed = ref.watch(recentlyViewedFilesProvider);
    final updated = ref.watch(recentFilesProvider);

    if (viewed.isEmpty && updated.isEmpty) {
      return _buildEmptyState();
    }

    return KeyboardDismissOnScroll(
      child: CustomScrollView(
        slivers: [
          if (viewed.isNotEmpty) ...[
            const _SectionHeader('Recently Viewed'),
            _fileSection(context, ref, viewed, bottomPadding: 4),
          ],
          if (updated.isNotEmpty) ...[
            const _SectionHeader('Recently Updated'),
            _fileSection(context, ref, updated, bottomPadding: 120),
          ],
        ],
      ),
    );
  }

  Widget _fileSection(
    BuildContext context,
    WidgetRef ref,
    List<SpaceFile> files, {
    required double bottomPadding,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
      sliver: StaggeredFileGrid(
        files: files,
        onTap: (file) => context.go('/notes/note/${file.id}'),
        onLongPress: (file) =>
            NotesListDialogs.showNoteContextMenu(context, ref, file),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.dim,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
