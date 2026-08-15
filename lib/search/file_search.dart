import '../file_types/file_type_registry.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';

const int rankExactName = 0;
const int rankNameWordPhrase = 1;
const int rankNamePhrase = 2;
const int rankNameAllWords = 3;
const int rankNameAllTerms = 4;
const int rankNameAndPath = 5;
const int rankContentOnly = 6;
const int rankNoMatch = 7;

/// True when [term] appears in [text] delimited by something other than a
/// letter or digit, so "mcu" matches "mcu chronological" and "notes-mcu.md"
/// but not the m-c-u buried inside "drumcut".
bool containsWord(String text, String term) {
  if (term.isEmpty) return false;
  var from = 0;
  while (true) {
    final at = text.indexOf(term, from);
    if (at < 0) return false;
    final beforeOk = at == 0 || !_isWordChar(text.codeUnitAt(at - 1));
    final end = at + term.length;
    final afterOk = end == text.length || !_isWordChar(text.codeUnitAt(end));
    if (beforeOk && afterOk) return true;
    from = at + 1;
  }
}

bool _isWordChar(int c) =>
    (c >= 48 && c <= 57) || (c >= 97 && c <= 122) || (c >= 65 && c <= 90);

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
  if (containsWord(lowerName, phrase)) return rankNameWordPhrase;
  if (lowerName.contains(phrase)) return rankNamePhrase;
  if (terms.every((t) => containsWord(lowerName, t))) return rankNameAllWords;
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

int credentialRank(String path, List<String> terms) {
  final lower = path.toLowerCase();
  const storePrefix = '.password-store/';
  final rel = lower.startsWith(storePrefix)
      ? lower.substring(storePrefix.length)
      : lower;
  final slash = rel.lastIndexOf('/');
  final site = slash >= 0 ? rel.substring(0, slash) : rel;
  final account = slash >= 0 ? rel.substring(slash + 1) : '';

  var siteHits = 0;
  for (final term in terms) {
    final inSite = site.contains(term);
    final inAccount = account.contains(term);
    if (!inSite && !inAccount) return rankNoMatch;
    if (inSite) siteHits++;
  }
  return terms.length - siteHits;
}

List<SpaceFile> searchAndRankCredentials(
    List<SpaceFile> credentials, List<String> terms) {
  if (terms.isEmpty) return credentials;
  final scored = <(int, SpaceFile)>[];
  for (final c in credentials) {
    final rank = credentialRank(c.path, terms);
    if (rank < rankNoMatch) scored.add((rank, c));
  }
  scored.sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    return a.$2.path.toLowerCase().compareTo(b.$2.path.toLowerCase());
  });
  return [for (final s in scored) s.$2];
}

List<Folder> rankFolders(List<Folder> folders, List<String> terms) {
  return [...folders]..sort((a, b) {
      final byRank =
          nameMatchRank(a.name, terms).compareTo(nameMatchRank(b.name, terms));
      if (byRank != 0) return byRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}
