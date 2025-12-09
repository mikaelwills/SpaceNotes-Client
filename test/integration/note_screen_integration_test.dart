import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacenotes_client/screens/note_screen.dart';
import 'package:spacenotes_client/repositories/spacetimedb_notes_repository.dart';
import 'package:spacenotes_client/providers/notes_providers.dart';
import 'package:spacenotes_client/repositories/shared_preferences_token_store.dart';
import 'package:uuid/uuid.dart';

/// Integration tests for NoteScreen that verify behavior against a live SpacetimeDB instance
///
/// REQUIREMENTS:
/// - SpacetimeDB server running at 100.84.184.121:3003
/// - Database: spacenotes
/// - These tests will create and delete real notes in the database
///
/// Run with: flutter test test/integration/note_screen_integration_test.dart
void main() {
  // SpacetimeDB configuration (from CLAUDE.md)
  const testHost = '100.84.184.121:3003';
  const testDatabase = 'spacenotes';

  // NOTE: We initialize/dispose repositories INSIDE each test to control lifecycle precisely.
  // This prevents the test framework from hanging while waiting for idle timers.

  group('Note Save Flow -', () {
    testWidgets('REGRESSION: Edits are saved to SpacetimeDB and acknowledged',
        (WidgetTester tester) async {
      late SpacetimeDbNotesRepository repository;
      late ProviderContainer container;

      const uuid = Uuid();
      final testPath = 'Test Notes/regression-test-${uuid.v4().substring(0, 8)}.md';
      const testContent = '# Regression Test\n\nThis is a test note.';

      String? createdNoteId;

      try {
        // Initialize and setup in Real Async
        await tester.runAsync(() async {
          repository = SpacetimeDbNotesRepository(
            host: testHost,
            database: testDatabase,
            authStorage: SharedPreferencesTokenStore(),
          );
          await repository.connectAndGetInitialData();

          final isConnected = await repository.checkConnection();
          expect(isConnected, true, reason: 'Failed to connect to SpacetimeDB');

          createdNoteId = await repository.createNote(testPath, '# \n');
          expect(createdNoteId, isNotNull);
          await Future.delayed(const Duration(seconds: 2));
        });

        // Create provider container
        container = ProviderContainer(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repository),
          ],
        );

        // Build the note screen
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: NoteScreen(notePath: testPath),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // WHEN: We edit the note content
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        await tester.enterText(textField, testContent);
        await tester.pump();

        // Wait for debounce timer to trigger save
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 2));
        });
        await tester.pump();

        final savedNote = await repository.getNote(createdNoteId!);
        expect(savedNote, isNotNull);
        expect(savedNote!.content, testContent,
            reason: 'Note content was not saved to SpacetimeDB');

        // AND: Subsequent edits should also save
        const updatedContent = '# Updated Title\n\nUpdated content.';
        await tester.enterText(textField, updatedContent);
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 2));
        });
        await tester.pump();

        final updatedNote = await repository.getNote(createdNoteId!);
        expect(updatedNote, isNotNull);
        expect(updatedNote!.content, updatedContent,
            reason: 'Subsequent edit was not saved - this is the regression!');
      } finally {
        // CRITICAL: Force dispose inside test body
        await tester.runAsync(() async {
          print('🛑 Cleaning up and disconnecting...');
          if (createdNoteId != null) {
            await repository.deleteNote(createdNoteId!);
          }
          repository.dispose();
          container.dispose();
        });

        await tester.pump();
      }
    });

    testWidgets('REGRESSION: Focus is not lost when save echo comes back',
        (WidgetTester tester) async {
      late SpacetimeDbNotesRepository repository;
      late ProviderContainer container;

      const uuid = Uuid();
      final testPath = 'Test Notes/focus-test-${uuid.v4().substring(0, 8)}.md';

      String? createdNoteId;

      try {
        // Initialize and setup in Real Async
        await tester.runAsync(() async {
          repository = SpacetimeDbNotesRepository(
            host: testHost,
            database: testDatabase,
            authStorage: SharedPreferencesTokenStore(),
          );
          await repository.connectAndGetInitialData();

          createdNoteId = await repository.createNote(testPath, '# \n');
          expect(createdNoteId, isNotNull);
          await Future.delayed(const Duration(seconds: 2));
        });

        container = ProviderContainer(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repository),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: NoteScreen(notePath: testPath),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // WHEN: We start editing and wait for the save echo
        final textField = find.byType(TextField);
        await tester.enterText(textField, '# Test\n\nTyping...');
        await tester.pump();

        // Verify field has focus
        final textFieldWidget = tester.widget<TextField>(textField);
        expect(textFieldWidget.focusNode?.hasFocus, true,
            reason: 'TextField should have focus during editing');

        // Wait for save and echo
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 2));
        });
        await tester.pump();

        // THEN: Focus should still be retained
        expect(textFieldWidget.focusNode?.hasFocus, true,
            reason: 'REGRESSION: Focus was lost when save echo came back!');
      } finally {
        // CRITICAL: Force dispose inside test body
        await tester.runAsync(() async {
          print('🛑 Cleaning up and disconnecting...');
          if (createdNoteId != null) {
            await repository.deleteNote(createdNoteId!);
          }
          repository.dispose();
          container.dispose();
        });

        await tester.pump();
      }
    });
  });

  group('External Change Handling -', () {
    testWidgets('External changes sync when not focused',
        (WidgetTester tester) async {
      late SpacetimeDbNotesRepository repository;
      late ProviderContainer container;

      const uuid = Uuid();
      final testPath = 'Test Notes/external-test-${uuid.v4().substring(0, 8)}.md';
      const initialContent = '# Initial Content\n\nOriginal text.';

      String? createdNoteId;

      try {
        // Initialize and setup in Real Async
        await tester.runAsync(() async {
          repository = SpacetimeDbNotesRepository(
            host: testHost,
            database: testDatabase,
            authStorage: SharedPreferencesTokenStore(),
          );
          await repository.connectAndGetInitialData();

          createdNoteId = await repository.createNote(testPath, initialContent);
          expect(createdNoteId, isNotNull);
          await Future.delayed(const Duration(seconds: 2));
        });

        container = ProviderContainer(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repository),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: NoteScreen(notePath: testPath),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Tap to enter edit mode, then unfocus
        await tester.tap(find.byType(GestureDetector));
        await tester.pump(const Duration(milliseconds: 500));

        // Unfocus by tapping outside (simulate losing focus)
        final textField = find.byType(TextField);
        final textFieldWidget = tester.widget<TextField>(textField);
        textFieldWidget.focusNode?.unfocus();
        await tester.pump();

        // WHEN: External change happens (simulating another device/client)
        const externalContent = '# Changed Externally\n\nThis was changed by another device.';
        await repository.updateNote(createdNoteId!, externalContent);

        // Wait for change to propagate
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 2));
        });
        await tester.pump();

        // THEN: The content should be synced
        final controller = textFieldWidget.controller;
        expect(controller?.text, externalContent,
            reason: 'External changes should sync when not focused');
      } finally {
        // CRITICAL: Force dispose inside test body
        await tester.runAsync(() async {
          print('🛑 Cleaning up and disconnecting...');
          if (createdNoteId != null) {
            await repository.deleteNote(createdNoteId!);
          }
          repository.dispose();
          container.dispose();
        });

        await tester.pump();
      }
    });

    testWidgets('Shows warning when external change happens during editing',
        (WidgetTester tester) async {
      late SpacetimeDbNotesRepository repository;
      late ProviderContainer container;

      const uuid = Uuid();
      final testPath = 'Test Notes/conflict-test-${uuid.v4().substring(0, 8)}.md';
      const initialContent = '# Initial Content\n\nOriginal text.';

      String? createdNoteId;

      try {
        // Initialize and setup in Real Async
        await tester.runAsync(() async {
          repository = SpacetimeDbNotesRepository(
            host: testHost,
            database: testDatabase,
            authStorage: SharedPreferencesTokenStore(),
          );
          await repository.connectAndGetInitialData();

          createdNoteId = await repository.createNote(testPath, initialContent);
          expect(createdNoteId, isNotNull);
          await Future.delayed(const Duration(seconds: 2));
        });

        container = ProviderContainer(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repository),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: NoteScreen(notePath: testPath),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Enter edit mode and start typing
        await tester.tap(find.byType(GestureDetector));
        await tester.pump(const Duration(milliseconds: 500));

        final textField = find.byType(TextField);
        await tester.enterText(textField, '# My Local Changes\n\nTyping...');
        await tester.pump();

        // Verify focus
        final textFieldWidget = tester.widget<TextField>(textField);
        expect(textFieldWidget.focusNode?.hasFocus, true);

        // WHEN: External change happens while editing
        const externalContent = '# External Change\n\nChanged by another device.';
        await repository.updateNote(createdNoteId!, externalContent);

        // Wait for change to propagate
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 2));
        });
        await tester.pump();

        // THEN: A warning snackbar should appear
        expect(find.text('Note was modified by another device'), findsOneWidget,
            reason: 'Should show conflict warning when editing');

        // AND: Local changes should NOT be overwritten
        expect(textFieldWidget.controller?.text, contains('My Local Changes'),
            reason: 'Local changes should be preserved during conflict');
      } finally {
        // CRITICAL: Force dispose inside test body
        await tester.runAsync(() async {
          print('🛑 Cleaning up and disconnecting...');
          if (createdNoteId != null) {
            await repository.deleteNote(createdNoteId!);
          }
          repository.dispose();
          container.dispose();
        });

        await tester.pump();
      }
    });
  });

  group('Rename Flow -', () {
    testWidgets('Note renames when title changes',
        (WidgetTester tester) async {
      late SpacetimeDbNotesRepository repository;
      late ProviderContainer container;

      const uuid = Uuid();
      final initialPath = 'Test Notes/original-name-${uuid.v4().substring(0, 8)}.md';
      const initialContent = '# Original Name\n\nContent.';

      String? createdNoteId;

      try {
        // Initialize and setup in Real Async
        await tester.runAsync(() async {
          repository = SpacetimeDbNotesRepository(
            host: testHost,
            database: testDatabase,
            authStorage: SharedPreferencesTokenStore(),
          );
          await repository.connectAndGetInitialData();

          createdNoteId = await repository.createNote(initialPath, initialContent);
          expect(createdNoteId, isNotNull);
          await Future.delayed(const Duration(seconds: 2));
        });

        container = ProviderContainer(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repository),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: NoteScreen(notePath: initialPath),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // WHEN: We change the title (first line)
        final textField = find.byType(TextField);
        const newContent = '# New Name\n\nSame content.';
        await tester.enterText(textField, newContent);
        await tester.pump();

        // Wait for rename debounce timer
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 3));
        });
        await tester.pump();

        // THEN: The note should be renamed in SpacetimeDB
        final renamedNote = await repository.getNote(createdNoteId!);
        expect(renamedNote, isNotNull);
        expect(renamedNote!.path, contains('New Name'),
            reason: 'Note should be renamed based on title change');
      } finally {
        // CRITICAL: Force dispose inside test body
        await tester.runAsync(() async {
          print('🛑 Cleaning up and disconnecting...');
          if (createdNoteId != null) {
            await repository.deleteNote(createdNoteId!);
          }
          repository.dispose();
          container.dispose();
        });

        await tester.pump();
      }
    });
  });
}
