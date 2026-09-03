import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class MiddlePaneMode {
  const MiddlePaneMode();

  const factory MiddlePaneMode.browse(String folderPath) = BrowseMode;

  const factory MiddlePaneMode.fileViewer(String noteId) = FileViewerMode;

  const factory MiddlePaneMode.searchResults(String previousFolderPath) =
      SearchResultsMode;
}

class BrowseMode extends MiddlePaneMode {
  final String folderPath;
  const BrowseMode(this.folderPath);
}

class FileViewerMode extends MiddlePaneMode {
  final String noteId;
  const FileViewerMode(this.noteId);
}

class SearchResultsMode extends MiddlePaneMode {
  final String previousFolderPath;
  const SearchResultsMode(this.previousFolderPath);
}

final middlePaneModeProvider = StateProvider<MiddlePaneMode>(
  (ref) => const MiddlePaneMode.browse(''),
);
