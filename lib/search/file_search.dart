import '../file_types/file_type_registry.dart';
import '../generated/folder.dart';
import '../generated/space_file.dart';

const int rankExactName = 0;
const int rankNamePhrase = 1;
const int rankNameAllTerms = 2;
const int rankNameAndPath = 3;
const int rankContentOnly = 4;
const int rankNoMatch = 5;

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

bool noteMatchesAllTerms(SpaceFile note, List<String> terms) =>
    noteSearchRank(note, terms) < rankNoMatch;

bool folderNameMatches(String folderName, List<String> terms) =>
    matchesAllTerms(folderName, terms);

int nameMatchRank(String name, List<String> terms) {
  if (terms.isEmpty) return rankNoMatch;
  final lower = name.toLowerCase();
  final phrase = terms.join(' ');
  if (lower == phrase) return rankExactName;
  if (lower.contains(phrase)) return rankNamePhrase;
  if (terms.every(lower.contains)) return rankNameAllTerms;
  return rankNoMatch;
}

int noteSearchRank(SpaceFile note, List<String> terms) {
  if (terms.isEmpty) return rankNoMatch;
  final byName = nameMatchRank(note.name, terms);
  if (byName < rankNameAndPath) return byName;

  final name = note.name.toLowerCase();
  final path = note.path.toLowerCase();
  if (terms.every((term) => name.contains(term) || path.contains(term))) {
    return rankNameAndPath;
  }

  final fileType = FileTypeRegistry.forFile(note);
  if (!fileType.hasTextRepresentation) return rankNoMatch;
  final content = note.content.toLowerCase();
  if (terms.every((term) =>
      name.contains(term) || path.contains(term) || content.contains(term))) {
    return rankContentOnly;
  }
  return rankNoMatch;
}

List<SpaceFile> rankNotes(List<SpaceFile> notes, List<String> terms) {
  return [...notes]..sort((a, b) {
      final byRank =
          noteSearchRank(a, terms).compareTo(noteSearchRank(b, terms));
      if (byRank != 0) return byRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

List<Folder> rankFolders(List<Folder> folders, List<String> terms) {
  return [...folders]..sort((a, b) {
      final byRank =
          nameMatchRank(a.name, terms).compareTo(nameMatchRank(b.name, terms));
      if (byRank != 0) return byRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}
