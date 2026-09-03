import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FolderBrowserViewMode { list, grid }

final folderBrowserViewModeProvider =
    StateProvider<FolderBrowserViewMode>((ref) => FolderBrowserViewMode.grid);
