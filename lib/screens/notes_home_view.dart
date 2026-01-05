import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../widgets/recent_notes_grid.dart';
import 'folder_list_view.dart';

class NotesHomeView extends ConsumerStatefulWidget {
  const NotesHomeView({super.key});

  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);
    final isSearching = searchQuery.trim().isNotEmpty;

    if (isSearching) {
      return const FolderListView(folderPath: '');
    }

    return PageView(
      controller: _pageController,
      dragStartBehavior: DragStartBehavior.start,
      children: const [
        RecentNotesGrid(),
        FolderListView(folderPath: ''),
      ],
    );
  }
}
