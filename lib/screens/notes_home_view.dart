import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dialogs/notes_list_dialogs.dart';
import '../providers/notes_providers.dart';
import '../theme/spacenotes_theme.dart';
import '../widgets/primitives/primitives.dart';
import '../widgets/recent_notes_grid.dart';
import 'folder_list_view.dart';

class NotesHomeView extends ConsumerStatefulWidget {
  const NotesHomeView({super.key});

  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = (_pageController.page ?? 0).round();
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    final isSearching = searchQuery.trim().isNotEmpty;
    final noteCount = ref.watch(recentNotesProvider).length;
    final folderCount =
        ref.watch(dynamicFolderContentsProvider('')).folders.length;

    final body = isSearching
        ? const FolderListView(folderPath: '')
        : PageView(
            controller: _pageController,
            dragStartBehavior: DragStartBehavior.start,
            children: const [
              RecentNotesGrid(),
              FolderListView(folderPath: ''),
            ],
          );

    final onFolders = isSearching || _currentPage == 1;

    return Stack(
      children: [
        Column(
          children: [
            _StatusLine(
              onFolders: onFolders,
              noteCount: noteCount,
              folderCount: folderCount,
              onTapRecent: () => _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
              onTapFolders: () => _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            ),
            Expanded(child: body),
          ],
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _HomeDock(),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final bool onFolders;
  final int noteCount;
  final int folderCount;
  final VoidCallback onTapRecent;
  final VoidCallback onTapFolders;

  const _StatusLine({
    required this.onFolders,
    required this.noteCount,
    required this.folderCount,
    required this.onTapRecent,
    required this.onTapFolders,
  });

  @override
  Widget build(BuildContext context) {
    return SnStatusLine(
      leading: onFolders
          ? GestureDetector(
              onTap: onTapRecent,
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Chevron(direction: AxisDirection.left),
                  SizedBox(width: 6),
                  SnUiText('recent',
                      color: SpaceNotesTheme.accent, fontSize: 10),
                ],
              ),
            )
          : SnStatusDiamond('recent', trail: '/ $noteCount notes'),
      trailing: onFolders
          ? SnStatusDiamond('folders', trail: '/ $folderCount')
          : GestureDetector(
              onTap: onTapFolders,
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SnUiText('folders',
                      color: SpaceNotesTheme.accent, fontSize: 10),
                  SizedBox(width: 6),
                  _Chevron(direction: AxisDirection.right),
                ],
              ),
            ),
    );
  }
}

class _Chevron extends StatelessWidget {
  final AxisDirection direction;
  const _Chevron({required this.direction});

  @override
  Widget build(BuildContext context) {
    final glyph = direction == AxisDirection.left ? '‹' : '›';
    return Text(
      glyph,
      style: const TextStyle(
        fontFamily: SpaceNotesTheme.fontMono,
        fontSize: 14,
        color: SpaceNotesTheme.accent,
        height: 1,
      ),
    );
  }
}

class _HomeDock extends ConsumerWidget {
  const _HomeDock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = ref.watch(_searchControllerProvider);

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            height: 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      SpaceNotesTheme.bg.withValues(alpha: 0.85),
                      SpaceNotesTheme.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SnField(
                      controller: searchController,
                      hint: 'search notes…',
                      leading: const Icon(Icons.search, size: 14),
                      onChanged: (v) {
                        ref.read(folderSearchQueryProvider.notifier).state = v;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DockIconButton(
                    icon: Icons.create_new_folder_outlined,
                    onTap: () => _HomeDock._newFolder(context, ref),
                    semanticLabel: 'new folder',
                  ),
                  const SizedBox(width: 8),
                  _DockIconButton(
                    icon: Icons.note_add_outlined,
                    onTap: () => _HomeDock._newNote(context, ref),
                    semanticLabel: 'new note',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _newFolder(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    NotesListDialogs.showCreateFolderDialog(context, ref);
  }

  static Future<void> _newNote(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final notePath = 'All Notes/Untitled-$timestamp.md';
    final repo = ref.read(notesRepositoryProvider);
    await repo.createNote(notePath, '');
  }
}

class _DockIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _DockIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border.all(
              color: SpaceNotesTheme.hairlineStrong,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusDock),
          ),
          child: Icon(icon, size: 16, color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }
}

final _searchControllerProvider = Provider.autoDispose<TextEditingController>(
  (ref) {
    final c = TextEditingController();
    ref.onDispose(c.dispose);
    return c;
  },
);
