import '../generated/note.dart';

/// Abstract repository for managing notes from various data sources
abstract class NotesRepository {
  /// Check if the repository is configured and ready to use
  Future<bool> isConfigured();

  /// Check if the connection to the data source is active
  Future<bool> checkConnection();

  /// Get a specific note by its ID
  Future<Note?> getNote(String id);

  /// Create a new note, returns the generated ID
  Future<String?> createNote(String path, String content);

  /// Update an existing note's content by ID
  Future<bool> updateNote(String id, String content);

  /// Delete a note by ID
  Future<bool> deleteNote(String id);

  /// Patch a note (insert content at specific position or heading)
  Future<bool> patchNote({
    required String path,
    required String content,
    int? position,
    String? heading,
  });

  /// Search notes by query
  Future<List<Note>> searchNotes(String query);
}
