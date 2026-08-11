import '../file_types/file_type_registry.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';

const int rankExactName = 0;
const int rankNamePhrase = 1;
const int rankNameAllTerms = 2;
const int rankNameAndPath = 3;
const int rankContentOnly = 4;
const int rankNoMatch = 5;

class SearchableFile {
  SearchableFile(this.file)
      : name = file.name.toLowerCase(),
        path = file.path.toLowerCase(),
        content = FileTypeRegistry.forFile(file).hasTextRepresentation
            ? file.content.toLowerCase()
            : null;

  final SpaceFile file;
  final String name;
  final String path;
  final String? content;
}

List<SearchableFile> buildSearchIndex(List<SpaceFile> notes) =>
    [for (final n in notes) SearchableFile(n)];

List<String> searchTerms(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .toList();

bool matchesAllTerms(String haystack, List<String> terms) {
  if (terms.isEmpty) return false;
  final lower = haystack.toLowerCase();
  return terms.every(lower.contains);
}

bool folderNameMatches(String folderName, List<String> terms) =>
    matchesAllTerms(folderName, terms);

int nameMatchRank(String name, List<String> terms) {
  if (terms.isEmpty) return rankNoMatch;
  final lower = name.toLowerCase();
  return _nameRankLower(lower, terms);
}

int _nameRankLower(String lowerName, List<String> terms) {
  final phrase = terms.join(' ');
  if (lowerName == phrase) return rankExactName;
  if (lowerName.contains(phrase)) return rankNamePhrase;
  if (terms.every(lowerName.contains)) return rankNameAllTerms;
  return rankNoMatch;
}

int indexedRank(SearchableFile entry, List<String> terms) {
  if (terms.isEmpty) return rankNoMatch;
  final byName = _nameRankLower(entry.name, terms);
  if (byName < rankNameAndPath) return byName;

  bool nameOrPathHasEvery() =>
      terms.every((t) => entry.name.contains(t) || entry.path.contains(t));

  if (nameOrPathHasEvery()) return rankNameAndPath;

  final content = entry.content;
  if (content == null) return rankNoMatch;
  final matchesInContent = terms.every((t) =>
      entry.name.contains(t) || entry.path.contains(t) || content.contains(t));
  return matchesInContent ? rankContentOnly : rankNoMatch;
}

List<SpaceFile> searchAndRank(List<SearchableFile> index, List<String> terms) {
  if (terms.isEmpty) return [for (final f in index) f.file];
  final scored = <(int, SearchableFile)>[];
  for (final f in index) {
    final rank = indexedRank(f, terms);
    if (rank < rankNoMatch) scored.add((rank, f));
  }
  scored.sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    return a.$2.name.compareTo(b.$2.name);
  });
  return [for (final s in scored) s.$2.file];
}

int noteSearchRank(SpaceFile note, List<String> terms) =>
    indexedRank(SearchableFile(note), terms);

bool noteMatchesAllTerms(SpaceFile note, List<String> terms) =>
    noteSearchRank(note, terms) < rankNoMatch;

List<SpaceFile> rankNotes(List<SpaceFile> notes, List<String> terms) =>
    searchAndRank(buildSearchIndex(notes), terms);

List<Folder> rankFolders(List<Folder> folders, List<String> terms) {
  return [...folders]..sort((a, b) {
      final byRank =
          nameMatchRank(a.name, terms).compareTo(nameMatchRank(b.name, terms));
      if (byRank != 0) return byRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}
