import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/generated/space_file.dart';
import 'package:spacenotes_client/search/file_search.dart';

SpaceFile _note({
  required String name,
  String path = '',
  String content = '',
  String extension = 'md',
}) =>
    SpaceFile.fromJson({
      'id': name,
      'name': name,
      'path': path.isEmpty ? name : path,
      'content': content,
      'extension': extension,
    });

void main() {
  group('rank ladder', () {
    test('exact name beats phrase beats all-terms beats content', () {
      final exact = _note(name: 'Good Flutter Architecture');
      final phrase = _note(name: 'Good Flutter Architecture Notes');
      final terms3 = _note(name: 'Flutter is good for architecture');
      final contentOnly =
          _note(name: 'CV', content: 'good flutter architecture experience');

      final terms = searchTerms('good flutter architecture');
      expect(indexedRank(SearchableFile(exact), terms), rankExactName);
      expect(indexedRank(SearchableFile(phrase), terms), rankNamePhrase);
      expect(indexedRank(SearchableFile(terms3), terms), rankNameAllTerms);
      expect(indexedRank(SearchableFile(contentOnly), terms), rankContentOnly);
    });

    test('non-match ranks below everything', () {
      final miss = _note(name: 'unrelated', content: 'nothing here');
      expect(
        indexedRank(SearchableFile(miss), searchTerms('flutter')),
        rankNoMatch,
      );
    });

    test('a non-text file never matches on content', () {
      final img = _note(name: 'photo', content: 'flutter', extension: 'png');
      expect(SearchableFile(img).content, isNull);
      expect(
        indexedRank(SearchableFile(img), searchTerms('flutter')),
        rankNoMatch,
      );
    });
  });

  group('credential ranking', () {
    SpaceFile cred(String path) => _note(name: path.split('/').last, path: path);

    test('site match ranks above account-only match', () {
      final results = searchAndRankCredentials([
        cred('.password-store/account.blizzard.com/rokitout@gmail.com.gpg'),
        cred('.password-store/mail.google.com/mikael@deadeye.eu.gpg'),
        cred('.password-store/account.beatport.com/rokitout@gmail.com.gpg'),
      ], searchTerms('google'));

      expect(results.first.path, contains('mail.google.com'));
      expect(results.length, 1);
    });

    test('searching a username surfaces every site using it', () {
      final results = searchAndRankCredentials([
        cred('.password-store/account.blizzard.com/rokitout@gmail.com.gpg'),
        cred('.password-store/account.beatport.com/rokitout@gmail.com.gpg'),
        cred('.password-store/account.jagex.com/other@gmail.com.gpg'),
      ], searchTerms('rokitout@gmail.com'));

      expect(results.length, 2);
    });

    test('site+account match beats site-only', () {
      final results = searchAndRankCredentials([
        cred('.password-store/accounts.google.com/someone@else.com.gpg'),
        cred('.password-store/accounts.google.com/rokitout@gmail.com.gpg'),
      ], searchTerms('google rokitout'));

      expect(results.first.path, contains('rokitout@gmail.com'));
    });
  });

  group('searchAndRank', () {
    test('orders by rank then name, dropping non-matches', () {
      final index = buildSearchIndex([
        _note(name: 'zzz', content: 'good flutter architecture'),
        _note(name: 'Good Flutter Architecture'),
        _note(name: 'unrelated'),
        _note(name: 'Good Flutter Architecture Guide'),
      ]);

      final result = searchAndRank(index, searchTerms('good flutter architecture'));

      expect(result.map((f) => f.name).toList(), [
        'Good Flutter Architecture',
        'Good Flutter Architecture Guide',
        'zzz',
      ]);
    });

    test('empty terms returns the whole index unranked', () {
      final index = buildSearchIndex([_note(name: 'a'), _note(name: 'b')]);
      expect(searchAndRank(index, searchTerms('')).length, 2);
    });
  });
}
