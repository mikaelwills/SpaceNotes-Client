import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../generated/client.dart';
import '../generated/folder.dart';
import '../generated/note.dart';

String _getDefaultHost() {
  if (kIsWeb) {
    return '${Uri.base.host}:5050';
  } else {
    return '0.0.0.0:5050';
  }
}

final notesRepositoryProvider = Provider<SpacetimeDbNotesRepository>((ref) {
  final repository = SpacetimeDbNotesRepository(
    host: _getDefaultHost(),
    database: 'spacenotes',
  );

  ref.onDispose(() {
    repository.dispose();
  });
  return repository;
});

/// Provider that exposes the SpacetimeDB client for connection status monitoring
final spacetimeClientProvider =
    StreamProvider.autoDispose<SpacetimeDbClient?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);

  // Watch the client stream - emits when client is created or reset
  return repository.watchClient();
});

final notesListProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchNotesList();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final currentFolderPathProvider = StateProvider<String>((ref) => '');

final currentNotePathProvider = StateProvider<String?>((ref) => null);

final filteredNotesProvider =
    Provider.autoDispose<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesListProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return notesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (notes) {
      if (searchQuery.trim().isEmpty) {
        return AsyncValue.data(notes);
      }

      final queryLower = searchQuery.toLowerCase();
      final filteredNotes = notes.where((note) {
        return note.name.toLowerCase().contains(queryLower) ||
            note.path.toLowerCase().contains(queryLower);
      }).toList();

      return AsyncValue.data(filteredNotes);
    },
  );
});

// Folder-specific providers for TopFolderListScreen
final foldersListProvider = StreamProvider<List<Folder>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchFoldersList();
});

final folderSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredFoldersProvider =
    Provider.autoDispose<AsyncValue<List<Folder>>>((ref) {
  final foldersAsync = ref.watch(foldersListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  return foldersAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (folders) {
      if (searchQuery.trim().isEmpty) {
        return AsyncValue.data(folders);
      }

      final queryLower = searchQuery.toLowerCase();
      final filteredFolders = folders.where((folder) {
        return folder.name.toLowerCase().contains(queryLower);
      }).toList();

      return AsyncValue.data(filteredFolders);
    },
  );
});

// Dynamic folder contents provider - works for any folder path (including root "")
final dynamicFolderContentsProvider = Provider.family.autoDispose<
    AsyncValue<({List<Folder> folders, List<Note> notes})>,
    String>((ref, currentPath) {
  final foldersAsync = ref.watch(foldersListProvider);
  final notesAsync = ref.watch(notesListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  // If either is loading, return loading
  if (foldersAsync.isLoading || notesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // If either has an error, return the first error
  if (foldersAsync.hasError) {
    return AsyncValue.error(
        foldersAsync.error!, foldersAsync.stackTrace ?? StackTrace.current);
  }
  if (notesAsync.hasError) {
    return AsyncValue.error(
        notesAsync.error!, notesAsync.stackTrace ?? StackTrace.current);
  }

  final allFolders = foldersAsync.valueOrNull ?? [];
  final allNotes = notesAsync.valueOrNull ?? [];

  // Normalize current path (empty string = root/top level)
  final normalizedPath = currentPath.isEmpty ? '' :
      (currentPath.endsWith('/') ? currentPath.substring(0, currentPath.length - 1) : currentPath);

  if (searchQuery.trim().isEmpty) {
    // Show direct children only (no search)
    List<Folder> childFolders;
    List<Note> childNotes;

    if (normalizedPath.isEmpty) {
      // Root level: show folders with depth 0
      childFolders = allFolders.where((folder) => folder.depth == 0).toList();
      childNotes = allNotes.where((note) => note.depth == 0).toList();
    } else {
      // Inside a folder: show direct subfolders and notes
      childFolders = allFolders.where((folder) {
        // Must start with current path + /
        if (!folder.path.startsWith('$normalizedPath/')) return false;
        // Get the part after current path
        final remainder = folder.path.substring(normalizedPath.length + 1);
        // Must not contain slashes (direct child only)
        return !remainder.contains('/');
      }).toList();

      final folderPathWithSlash = '$normalizedPath/';
      childNotes = allNotes.where((note) => note.folderPath == folderPathWithSlash).toList();
    }

    return AsyncValue.data((folders: childFolders, notes: childNotes));
  }

  // Search mode: search ALL folders and notes (not relative to current path)
  final queryLower = searchQuery.toLowerCase();

  final filteredFolders = allFolders.where((folder) {
    return folder.name.toLowerCase().contains(queryLower);
  }).toList();

  final filteredNotes = allNotes.where((note) {
    return note.name.toLowerCase().contains(queryLower) ||
        note.path.toLowerCase().contains(queryLower);
  }).toList();

  return AsyncValue.data((folders: filteredFolders, notes: filteredNotes));
});

// Provider for notes in a specific folder
final folderNotesProvider = Provider.family
    .autoDispose<AsyncValue<List<Note>>, String>((ref, folderPath) {
  final notesAsync = ref.watch(notesListProvider);

  return notesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (notes) {
      // Ensure folder path has trailing slash for comparison
      final folderPathWithSlash =
          folderPath.endsWith('/') ? folderPath : '$folderPath/';
      final folderNotes = notes
          .where((note) => note.folderPath == folderPathWithSlash)
          .toList();
      return AsyncValue.data(folderNotes);
    },
  );
});

// Provider for subfolders within a specific folder
final folderSubfoldersProvider = Provider.family
    .autoDispose<AsyncValue<List<Folder>>, String>((ref, folderPath) {
  final foldersAsync = ref.watch(foldersListProvider);

  return foldersAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (folders) {
      // Normalize the parent folder path (no trailing slash)
      final normalizedPath = folderPath.endsWith('/')
          ? folderPath.substring(0, folderPath.length - 1)
          : folderPath;

      // Find direct subfolders (folders whose path starts with parentPath/
      // and has no additional slashes after that)
      final subfolders = folders.where((folder) {
        // Must start with parent path + /
        if (!folder.path.startsWith('$normalizedPath/')) return false;

        // Get the part after the parent path
        final remainder = folder.path.substring(normalizedPath.length + 1);

        // Must not contain any slashes (direct child only)
        return !remainder.contains('/');
      }).toList();

      return AsyncValue.data(subfolders);
    },
  );
});

// Provider for recently edited notes (top 20)
// Reactively updates when notes change in the cache
final recentNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesListProvider);

  return notesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (notes) {
      if (notes.isEmpty) {
        return const AsyncValue.data([]);
      }

      // Sort by modifiedTime descending (most recently edited first)
      final sortedNotes = notes.toList();
      sortedNotes.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));

      // Return top 5
      return AsyncValue.data(sortedNotes.take(20).toList());
    },
  );
});
