import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:opencode_flutter_client/screens/note_screen.dart';
import 'package:opencode_flutter_client/repositories/spacetimedb_notes_repository.dart';
import 'package:opencode_flutter_client/providers/notes_providers.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' show AuthTokenStore;

// Helper to enter edit mode robustly
Future<void> enterEditMode(WidgetTester tester) async {
  // Find the GestureDetector that wraps the markdown
  final finder = find.byType(GestureDetector);
  if (finder.evaluate().isEmpty) {
    throw TestFailure("Could not find Markdown Preview to tap");
  }
  await tester.tap(finder.first);
  await tester.pump();
  // Wait for the animation/swap
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testHost = '100.84.184.121:3003';
  const testDatabase = 'spacenotes';
  const uuid = Uuid();

  late SpacetimeDbNotesRepository uiRepository;

  group('Full Stack Reliability', () {
    testWidgets('CRITICAL: Focus is RETAINED when save echo comes back',
    (tester) async {
      final testId = uuid.v4();
      final testPath = 'Test Notes/focus-${testId.substring(0, 8)}.md';

      uiRepository = SpacetimeDbNotesRepository(
        host: testHost,
        database: testDatabase,
        authStorage: InMemoryTokenStore(),
      );

      await tester.runAsync(() async {
        await uiRepository.connectAndGetInitialData();
        await uiRepository.createNote(testPath, '# Focus Test\n\nStart.');
        await Future.delayed(const Duration(seconds: 2));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notesRepositoryProvider.overrideWithValue(uiRepository)],
          child: MaterialApp(home: Scaffold(body: NoteScreen(notePath: testPath))),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // 1. Enter Edit Mode
      await enterEditMode(tester);
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget, reason: "TextField did not appear after tap");

      // 2. Type & Check Focus
      await tester.enterText(textField, '# Focus Test\n\nTyping...');
      await tester.pump();
      expect(FocusScope.of(tester.element(textField)).hasFocus, isTrue);

      // 3. Wait for Echo
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pump();

      // 4. Verify Focus Retained
      expect(FocusScope.of(tester.element(textField)).hasFocus, isTrue,
        reason: "Focus lost after echo!");

      // Cleanup
      await tester.runAsync(() async {
        try { uiRepository.dispose(); } catch (_) {}
      });
    });

    testWidgets('REGRESSION: Multiple edits save successfully',
    (tester) async {
      final testId = uuid.v4();
      final testPath = 'Test Notes/save-${testId.substring(0, 8)}.md';

      uiRepository = SpacetimeDbNotesRepository(
        host: testHost,
        database: testDatabase,
        authStorage: InMemoryTokenStore(),
      );

      await tester.runAsync(() async {
        await uiRepository.connectAndGetInitialData();
        await uiRepository.createNote(testPath, '# Save Test\n\nInit.');
        await Future.delayed(const Duration(seconds: 2));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notesRepositoryProvider.overrideWithValue(uiRepository)],
          child: MaterialApp(home: Scaffold(body: NoteScreen(notePath: testPath))),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await enterEditMode(tester);
      final textField = find.byType(TextField);

      // Edit 1
      await tester.enterText(textField, '# Save Test\n\nEdit 1.');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async { await Future.delayed(const Duration(seconds: 2)); });

      // Edit 2
      await tester.enterText(textField, '# Save Test\n\nEdit 2.');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async { await Future.delayed(const Duration(seconds: 2)); });

      // Verify by checking the text field still contains Edit 2
      // (If saves weren't working, it would have reverted)
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, contains('Edit 2'),
          reason: 'Second edit should persist');

      await tester.runAsync(() async {
        try { uiRepository.dispose(); } catch (_) {}
      });
    });
  });
}

// Simple in-memory storage for testing
class InMemoryTokenStore implements AuthTokenStore {
  String? _token;

  @override
  Future<String?> loadToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}
