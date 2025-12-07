import '../generated/note.dart';
import '../services/notes_api_service.dart';
import 'notes_repository.dart';

/// Notes repository implementation using Obsidian REST API
/// NOTE: This is currently unused - app uses SpacetimeDB repository
/// Kept for potential future use with REST API integration
class ObsidianNotesRepository implements NotesRepository {
  final NotesService _service;

  ObsidianNotesRepository(this._service);

  @override
  Future<bool> isConfigured() async {
    return await _service.isConfigured();
  }

  @override
  Future<bool> checkConnection() async {
    return await _service.checkConnection();
  }


  @override
  Future<Note?> getNote(String id) async {
    // TODO: Obsidian API is path-based, would need ID->path mapping
    return null;
  }

  @override
  Future<String?> createNote(String path, String content) async {
    // TODO: Call API service and generate UUID for created note
    return null;
  }

  @override
  Future<bool> updateNote(String id, String content) async {
    // TODO: Obsidian API is path-based, would need ID->path mapping
    return false;
  }

  @override
  Future<bool> deleteNote(String id) async {
    // TODO: Obsidian API is path-based, would need ID->path mapping
    return false;
  }

  @override
  Future<bool> patchNote({
    required String path,
    required String content,
    int? position,
    String? heading,
  }) async {
    return await _service.patchNote(
      path: path,
      content: content,
      position: position,
      heading: heading,
    );
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    // TODO: Convert ApiNote list to Note list with UUID generation
    return [];
  }
}
