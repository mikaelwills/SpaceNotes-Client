import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
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

/// Subscribe [ref] to a [ValueListenable] so the provider rebuilds on change.
/// Returns the current value.
T watchListenable<T>(Ref ref, ValueListenable<T> listenable) {
  void listener() {
    ref.invalidateSelf();
  }

  listenable.addListener(listener);
  ref.onDispose(() => listenable.removeListener(listener));
  return listenable.value;
}

/// Current SpacetimeDB client (null before connect, null after reset)
final spacetimeClientProvider = Provider<SpacetimeDbClient?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return watchListenable(ref, repository.clientNotifier);
});

final notesListProvider = Provider<List<Note>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.note.rows);
  final sorted = rows.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return sorted;
});

final foldersListProvider = Provider<List<Folder>>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.folder.rows);
  final sorted = rows.toList()
    ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return sorted;
});

final noteByIdProvider = Provider.family<Note?, String>((ref, id) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.note.rowNotifier(id));
});

final folderByIdProvider = Provider.family<Folder?, String>((ref, path) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.folder.rowNotifier(path));
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final currentFolderPathProvider = StateProvider<String>((ref) => '');

final currentNotePathProvider = StateProvider<String?>((ref) => null);

List<String> searchTerms(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .toList();

bool noteMatchesAllTerms(Note note, List<String> terms) {
  final name = note.name.toLowerCase();
  final path = note.path.toLowerCase();
  final content = note.content.toLowerCase();
  return terms.every((term) =>
      name.contains(term) || path.contains(term) || content.contains(term));
}

List<Note> _rankNotesByNameMatch(List<Note> notes, List<String> terms) {
  final nameMatches = <Note>[];
  final otherMatches = <Note>[];
  for (final note in notes) {
    final name = note.name.toLowerCase();
    if (terms.every((term) => name.contains(term))) {
      nameMatches.add(note);
    } else {
      otherMatches.add(note);
    }
  }
  nameMatches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  otherMatches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [...nameMatches, ...otherMatches];
}

final filteredNotesProvider = Provider.autoDispose<List<Note>>((ref) {
  final notes = ref.watch(notesListProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  if (searchQuery.trim().isEmpty) return notes;

  final terms = searchTerms(searchQuery);
  if (terms.isEmpty) return notes;
  final matches =
      notes.where((note) => noteMatchesAllTerms(note, terms)).toList();
  return _rankNotesByNameMatch(matches, terms);
});

final folderSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredFoldersProvider = Provider.autoDispose<List<Folder>>((ref) {
  final folders = ref.watch(foldersListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  if (searchQuery.trim().isEmpty) return folders;

  final terms = searchTerms(searchQuery);
  if (terms.isEmpty) return folders;
  return folders.where((folder) {
    final name = folder.name.toLowerCase();
    return terms.every((term) => name.contains(term));
  }).toList();
});

final dynamicFolderContentsProvider = Provider.family
    .autoDispose<({List<Folder> folders, List<Note> notes}), String>(
        (ref, currentPath) {
  final allFolders = ref.watch(foldersListProvider);
  final allNotes = ref.watch(notesListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  final normalizedPath = currentPath.isEmpty
      ? ''
      : (currentPath.endsWith('/')
          ? currentPath.substring(0, currentPath.length - 1)
          : currentPath);

  if (searchQuery.trim().isEmpty) {
    List<Folder> childFolders;
    List<Note> childNotes;

    if (normalizedPath.isEmpty) {
      childFolders = allFolders.where((folder) => folder.depth == 0).toList();
      childNotes = allNotes.where((note) => note.depth == 0).toList();
    } else {
      childFolders = allFolders.where((folder) {
        if (!folder.path.startsWith('$normalizedPath/')) return false;
        final remainder = folder.path.substring(normalizedPath.length + 1);
        return !remainder.contains('/');
      }).toList();

      final folderPathWithSlash = '$normalizedPath/';
      childNotes = allNotes
          .where((note) => note.folderPath == folderPathWithSlash)
          .toList();
    }

    return (folders: childFolders, notes: childNotes);
  }

  final terms = searchTerms(searchQuery);

  final filteredFolders = allFolders.where((folder) {
    final name = folder.name.toLowerCase();
    return terms.every((term) => name.contains(term));
  }).toList();

  final filteredNotes =
      allNotes.where((note) => noteMatchesAllTerms(note, terms)).toList();

  return (
    folders: filteredFolders,
    notes: _rankNotesByNameMatch(filteredNotes, terms)
  );
});

final folderNotesProvider =
    Provider.family.autoDispose<List<Note>, String>((ref, folderPath) {
  final notes = ref.watch(notesListProvider);
  final folderPathWithSlash =
      folderPath.endsWith('/') ? folderPath : '$folderPath/';
  return notes.where((note) => note.folderPath == folderPathWithSlash).toList();
});

final folderSubfoldersProvider =
    Provider.family.autoDispose<List<Folder>, String>((ref, folderPath) {
  final folders = ref.watch(foldersListProvider);
  final normalizedPath = folderPath.endsWith('/')
      ? folderPath.substring(0, folderPath.length - 1)
      : folderPath;

  return folders.where((folder) {
    if (!folder.path.startsWith('$normalizedPath/')) return false;
    final remainder = folder.path.substring(normalizedPath.length + 1);
    return !remainder.contains('/');
  }).toList();
});

/// Recently edited notes (top 20, by modifiedTime desc).
final recentNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesListProvider);
  if (notes.isEmpty) return const [];

  final sorted = notes.toList()
    ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
  return sorted.take(20).toList();
});
