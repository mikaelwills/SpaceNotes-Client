import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Column(
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
    );
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = (_pageController.page ?? 0).round();
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
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
