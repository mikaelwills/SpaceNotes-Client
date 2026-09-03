import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/blocs/desktop_notes/desktop_notes_bloc.dart';
import 'package:spacenotes_client/blocs/desktop_notes/desktop_notes_event.dart';
import 'package:spacenotes_client/blocs/desktop_notes/desktop_notes_state.dart';

void main() {
  group('DesktopNotesBloc - slice 4 per-tab parent folder', () {
    blocTest<DesktopNotesBloc, DesktopNotesState>(
      'OpenNote records the parent folder it was opened from',
      build: DesktopNotesBloc.new,
      act: (bloc) => bloc.add(OpenNote('n1', parentFolderPath: 'Projects')),
      expect: () => [
        predicate<DesktopNotesState>(
          (s) =>
              s.openNoteIds.contains('n1') &&
              s.parentFolderByNoteId['n1'] == 'Projects',
        ),
      ],
    );

    blocTest<DesktopNotesBloc, DesktopNotesState>(
      'opening a second note from a different folder keeps both parent folders '
      'independent',
      build: DesktopNotesBloc.new,
      act: (bloc) => bloc
        ..add(OpenNote('n1', parentFolderPath: 'x'))
        ..add(OpenNote('n2', parentFolderPath: 'y')),
      skip: 1,
      expect: () => [
        predicate<DesktopNotesState>(
          (s) =>
              s.parentFolderByNoteId['n1'] == 'x' &&
              s.parentFolderByNoteId['n2'] == 'y',
        ),
      ],
    );

    blocTest<DesktopNotesBloc, DesktopNotesState>(
      'switching back to an already-open note does not overwrite its recorded '
      'parent folder',
      build: DesktopNotesBloc.new,
      act: (bloc) => bloc
        ..add(OpenNote('n1', parentFolderPath: 'x'))
        ..add(OpenNote('n2', parentFolderPath: 'y'))
        ..add(OpenNote('n1', parentFolderPath: 'z')),
      skip: 2,
      expect: () => [
        predicate<DesktopNotesState>(
          (s) =>
              s.activeNoteId == 'n1' && s.parentFolderByNoteId['n1'] == 'x',
        ),
      ],
    );

    blocTest<DesktopNotesBloc, DesktopNotesState>(
      'CloseNote removes the closed note\'s parent-folder entry',
      build: DesktopNotesBloc.new,
      act: (bloc) => bloc
        ..add(OpenNote('n1', parentFolderPath: 'x'))
        ..add(CloseNote('n1')),
      skip: 1,
      expect: () => [
        predicate<DesktopNotesState>(
          (s) =>
              !s.openNoteIds.contains('n1') &&
              !s.parentFolderByNoteId.containsKey('n1'),
        ),
      ],
    );

    blocTest<DesktopNotesBloc, DesktopNotesState>(
      'eviction on exceeding maxOpenNotes removes the evicted note\'s parent '
      'folder entry too',
      build: () => DesktopNotesBloc()..add(SetMaxOpenNotes(2)),
      act: (bloc) => bloc
        ..add(OpenNote('n1', parentFolderPath: 'a'))
        ..add(OpenNote('n2', parentFolderPath: 'b'))
        ..add(OpenNote('n3', parentFolderPath: 'c')),
      skip: 3,
      expect: () => [
        predicate<DesktopNotesState>(
          (s) =>
              s.openNoteIds.length == 2 &&
              !s.openNoteIds.contains('n1') &&
              !s.parentFolderByNoteId.containsKey('n1') &&
              s.parentFolderByNoteId['n2'] == 'b' &&
              s.parentFolderByNoteId['n3'] == 'c',
        ),
      ],
    );
  });
}
