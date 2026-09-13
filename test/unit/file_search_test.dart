import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/generated/space_file.dart';
import 'package:spacenotes_client/search/file_search.dart';

SpaceFile _note({
  required String name,
  String path = '',
  String extension = 'md',
  int modifiedTime = 0,
}) =>
    SpaceFile.fromJson({
      'id': name,
      'name': name,
      'path': path.isEmpty ? name : path,
      'extension': extension,
      'modifiedTime': modifiedTime,
    });

void main() {
  group('rank ladder', () {
    test('exact name beats phrase beats all-terms beats name-and-path', () {
      final exact = _note(name: 'Good Flutter Architecture');
      final phrase = _note(name: 'Good Flutter Architecture Notes');
      final terms3 = _note(name: 'Flutter is good for architecture');
      final nameAndPath =
          _note(name: 'architecture', path: 'good/flutter/architecture.md');

      final terms = searchTerms('good flutter architecture');
      expect(indexedRank(SearchableFile(exact), terms), rankExactName);
      expect(
          indexedRank(SearchableFile(phrase), terms), rankNameStandalonePhrase);
      expect(
          indexedRank(SearchableFile(terms3), terms), rankNameStandaloneWords);
      expect(indexedRank(SearchableFile(nameAndPath), terms), rankNameAndPath);
    });

    test('a whole-word match outranks the same letters inside another word',
        () {
      final wholeWord = _note(name: 'MCU chronological');
      final buried = _note(name: 'bulk-rerender-drumcuts-beat-snapped');
      final terms = searchTerms('mcu');

      final wholeWordRank = indexedRank(SearchableFile(wholeWord), terms);
      final buriedRank = indexedRank(SearchableFile(buried), terms);

      expect(wholeWordRank, lessThan(buriedRank));
      expect(
        searchAndRank(
          buildSearchIndex([buried, wholeWord]),
          terms,
        ).first.name,
        'MCU chronological',
      );
    });

    test('a standalone term outranks the same term inside a hyphenated slug',
        () {
      final terms = searchTerms('mcu');
      final standalone = _note(name: 'MCU Watch Order (movies)');
      final inSlug =
          _note(name: '2026-07-12-1-grab-into-dotfiles-mcu-download');
      final buried = _note(name: 'bulk-rerender-drumcuts-beat-snapped');

      final standaloneRank = indexedRank(SearchableFile(standalone), terms);
      final slugRank = indexedRank(SearchableFile(inSlug), terms);
      final buriedRank = indexedRank(SearchableFile(buried), terms);

      expect(standaloneRank, lessThan(slugRank));
      expect(slugRank, lessThan(buriedRank));
    });

    test('his real MCU search puts the MCU-titled note first', () {
      final notes = [
        _note(name: '2026-06-25-1-notes-assistant-finance-career-mcu'),
        _note(name: '2026-07-12-1-grab-into-dotfiles-mcu-download'),
        _note(name: '2026-08-08-1-cloudflare-os-calf-recovery-mcu'),
        _note(name: 'MCU Watch Order (movies)'),
        _note(name: '2026-05-04 - Drumcut bulk + Renders page'),
        _note(name: 'bulk-rerender-drumcuts-beat-snapped'),
        _note(name: 'kick-remaining-slave-tensor-drumcuts'),
      ];

      final ordered =
          searchAndRank(buildSearchIndex(notes), searchTerms('mcu'));

      expect(ordered.first.name, 'MCU Watch Order (movies)');
    });

    test('a term bounded by punctuation still counts as a whole word', () {
      final terms = searchTerms('mcu');
      for (final name in [
        'MCU chronological',
        '2026-07-12-1-grab-into-dotfiles-mcu-download',
        'notes.mcu.md',
        'mcu',
      ]) {
        expect(indexedRank(SearchableFile(_note(name: name)), terms),
            lessThan(rankNamePhrase + 1),
            reason: name);
      }
    });

    test('non-match ranks below everything', () {
      final miss = _note(name: 'unrelated');
      expect(
        indexedRank(SearchableFile(miss), searchTerms('flutter')),
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
        _note(name: 'zzz', path: 'good/flutter/architecture/zzz.md'),
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

    test('within one rank the most recently modified file comes first', () {
      final index = buildSearchIndex([
        _note(name: 'Blood Bound Master 0509', modifiedTime: 100),
        _note(name: 'Blood Bound Master 0509 1', modifiedTime: 200),
        _note(name: 'Blood Bound Master 0509 3', modifiedTime: 400),
        _note(name: 'Blood Bound Master 0509 2', modifiedTime: 300),
      ]);

      final result = searchAndRank(index, searchTerms('blood'));

      expect(result.map((f) => f.name).toList(), [
        'Blood Bound Master 0509 3',
        'Blood Bound Master 0509 2',
        'Blood Bound Master 0509 1',
        'Blood Bound Master 0509',
      ]);
    });

    test('empty terms returns the whole index unranked', () {
      final index = buildSearchIndex([_note(name: 'a'), _note(name: 'b')]);
      expect(searchAndRank(index, searchTerms('')).length, 2);
    });
  });
}
