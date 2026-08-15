import 'package:collection/collection.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/widgets.dart' show FocusNode;
import 'package:spacenotes_pgp/spacenotes_pgp.dart';
import '../generated/client.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';
import '../services/credential_key_store.dart';
import '../services/credential_name_deriver.dart';
import '../services/credential_writer.dart';
import '../services/debug_logger.dart';
import '../file_types/file_type_registry.dart';
import '../search/file_search.dart';

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

/// The notes-domain client — files and folders (null before connect, null
/// after reset). Its socket carries the large `space_file` snapshot.
final notesClientProvider = Provider<SpacetimeDbClient?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return watchListenable(ref, repository.notesClientNotifier);
});

/// The chat-domain client — agents, messages, calls and presence. Deliberately
/// a separate socket so chat hydration never queues behind the notes snapshot.
final chatClientProvider = Provider<SpacetimeDbClient?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return watchListenable(ref, repository.chatClientNotifier);
});

final fileListProvider = Provider<List<SpaceFile>>((ref) {
  final client = ref.watch(notesClientProvider);
  if (client == null) {
    debugLogger.warning('NOTES_LIST', 'client is null -> rendering 0 notes');
    return const [];
  }
  final rows = watchListenable(ref, client.spaceFile.rows);
  if (rows.isEmpty) {
    debugLogger.warning('NOTES_LIST', 'client present but spaceFile.rows is 0');
  }
  final sorted = rows.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return sorted;
});

final foldersListProvider = Provider<List<Folder>>((ref) {
  final client = ref.watch(notesClientProvider);
  if (client == null) return const [];
  final rows = watchListenable(ref, client.folder.rows);
  final sorted = rows.toList()
    ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return sorted;
});

final fileByIdProvider = Provider.family<SpaceFile?, String>((ref, id) {
  final client = ref.watch(notesClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.spaceFile.rowNotifier(id));
});

final credentialStoreDotfileProvider =
    Provider.family<String?, String>((ref, fileName) {
  final files = ref.watch(fileListProvider);
  final row = files.firstWhereOrNull(
    (f) => f.path == '${CredentialNameDeriver.storeRoot}/$fileName',
  );
  return row?.content;
});

final credentialWriterProvider = Provider<CredentialWriter?>((ref) {
  final gpgId = ref.watch(
    credentialStoreDotfileProvider('.gpg-id'),
  );
  final publicKeys = ref.watch(
    credentialStoreDotfileProvider('.gpg-pubkeys.asc'),
  );
  if (gpgId == null || publicKeys == null) return null;

  final repository = ref.watch(notesRepositoryProvider);
  final keyStore = CredentialKeyStore();

  return CredentialWriter(
    gpgId: gpgId,
    publicKeysArmored: publicKeys,
    encrypt: SpaceNotesPgp.encrypt,
    decrypt: SpaceNotesPgp.decrypt,
    readPrivateKey: keyStore.read,
    upsert: repository.writeCredential,
  );
});

final folderByIdProvider = Provider.family<Folder?, String>((ref, path) {
  final client = ref.watch(notesClientProvider);
  if (client == null) return null;
  return watchListenable(ref, client.folder.rowNotifier(path));
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final currentFolderPathProvider = StateProvider<String>((ref) => '');

final currentNotePathProvider = StateProvider<String?>((ref) => null);

final mobileInputFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'mobileBottomInput');
  ref.onDispose(node.dispose);
  return node;
});

final noteSearchIndexProvider = Provider<List<SearchableFile>>((ref) {
  final notes = ref.watch(fileListProvider);
  return buildSearchIndex(notes);
});

final filteredFilesProvider = Provider.autoDispose<List<SpaceFile>>((ref) {
  final searchQuery = ref.watch(searchQueryProvider);
  if (searchQuery.trim().isEmpty) return ref.watch(fileListProvider);

  final terms = searchTerms(searchQuery);
  if (terms.isEmpty) return ref.watch(fileListProvider);
  return searchAndRank(ref.watch(noteSearchIndexProvider), terms);
});

final folderSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredFoldersProvider = Provider.autoDispose<List<Folder>>((ref) {
  final folders = ref.watch(foldersListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  if (searchQuery.trim().isEmpty) return folders;

  final terms = searchTerms(searchQuery);
  if (terms.isEmpty) return folders;
  return rankFolders(
    folders.where((folder) => folderNameMatches(folder.name, terms)).toList(),
    terms,
  );
});

final dynamicFolderContentsProvider = Provider.family
    .autoDispose<({List<Folder> folders, List<SpaceFile> notes}), String>(
        (ref, currentPath) {
  final allFolders = ref.watch(foldersListProvider);
  final allNotes = ref.watch(fileListProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  final normalizedPath = currentPath.isEmpty
      ? ''
      : (currentPath.endsWith('/')
          ? currentPath.substring(0, currentPath.length - 1)
          : currentPath);

  if (searchQuery.trim().isEmpty) {
    List<Folder> childFolders;
    List<SpaceFile> childNotes;

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

  final filteredFolders = allFolders
      .where((folder) => folderNameMatches(folder.name, terms))
      .toList();

  return (
    folders: filteredFolders,
    notes: searchAndRank(ref.watch(noteSearchIndexProvider), terms),
  );
});

final folderFilesProvider =
    Provider.family.autoDispose<List<SpaceFile>, String>((ref, folderPath) {
  final notes = ref.watch(fileListProvider);
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
final recentFilesProvider = Provider<List<SpaceFile>>((ref) {
  final notes = ref.watch(fileListProvider);
  if (notes.isEmpty) return const [];

  final sorted = notes.toList()
    ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
  return sorted.take(20).toList();
});

/// Every credential in the store, sorted by site then account.
final credentialsProvider = Provider<List<SpaceFile>>((ref) {
  final files = ref.watch(fileListProvider);
  final credentials = files
      .where((f) => FileTypeRegistry.forFile(f).extension == 'gpg')
      .toList()
    ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return credentials;
});

final credentialFilterProvider = StateProvider<String>((ref) => '');

/// Credentials matching the filter, on site or account.
final filteredCredentialsProvider = Provider<List<SpaceFile>>((ref) {
  final credentials = ref.watch(credentialsProvider);
  final terms = searchTerms(ref.watch(credentialFilterProvider));
  if (terms.isEmpty) return credentials;

  return searchAndRankCredentials(credentials, terms);
});
