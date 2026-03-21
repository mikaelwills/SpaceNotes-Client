import 'dart:async';
import '../models/opencode_event.dart';
import '../repositories/spacetimedb_notes_repository.dart' show SpacetimeDbNotesRepository;
import 'opencode_client.dart';
import 'sse_service.dart';
import 'debug_logger.dart';

class _PendingTitle {
  final String noteId;
  final String currentPath;

  _PendingTitle({
    required this.noteId,
    required this.currentPath,
  });
}

class TitleGenerationService {
  final OpenCodeClient _openCodeClient;
  final SSEService _sseService;
  SpacetimeDbNotesRepository? _repo;

  String? _titleSessionId;
  final Map<String, _PendingTitle> _pendingNotes = {};
  final Set<String> _completedNotes = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, String> _noteContents = {};
  final Map<String, String> _notePaths = {};
  StreamSubscription<OpenCodeEvent>? _sseSubscription;
  String _accumulatedText = '';
  String? _firstMessageId;
  bool _seenAssistantMessage = false;
  Timer? _timeoutTimer;

  TitleGenerationService({
    required OpenCodeClient openCodeClient,
    required SSEService sseService,
  })  : _openCodeClient = openCodeClient,
        _sseService = sseService;

  void setRepository(SpacetimeDbNotesRepository repo) {
    _repo = repo;
  }

  void onNoteSaved(String noteId, String content, String path) {
    final fileName = path.split('/').last.replaceAll('.md', '');
    if (!fileName.toLowerCase().startsWith('untitled')) return;
    if (content.length < 10) return;
    if (_completedNotes.contains(noteId) || _pendingNotes.containsKey(noteId)) return;

    _noteContents[noteId] = content;
    _notePaths[noteId] = path;

    _debounceTimers[noteId]?.cancel();
    _debounceTimers[noteId] = Timer(const Duration(seconds: 1), () {
      _debounceTimers.remove(noteId);
      _fireGenerateTitle(noteId);
    });
  }

  void triggerImmediate(String noteId, {String? content, String? path}) {
    if (_completedNotes.contains(noteId) || _pendingNotes.containsKey(noteId)) return;

    if (content != null && path != null) {
      _noteContents[noteId] = content;
      _notePaths[noteId] = path;
    }

    final timer = _debounceTimers.remove(noteId);
    timer?.cancel();

    if (_noteContents.containsKey(noteId)) {
      _fireGenerateTitle(noteId);
    }
  }

  void _fireGenerateTitle(String noteId) {
    final content = _noteContents.remove(noteId);
    final path = _notePaths.remove(noteId);
    if (content == null || path == null || _repo == null) return;

    generateTitle(noteId: noteId, content: content, currentPath: path);
  }

  Future<void> generateTitle({
    required String noteId,
    required String content,
    required String currentPath,
  }) async {
    if (content.length < 10) return;
    if (_pendingNotes.containsKey(noteId) || _completedNotes.contains(noteId)) return;
    if (_repo == null) return;

    final fileName = currentPath.split('/').last.replaceAll('.md', '');
    if (!fileName.toLowerCase().startsWith('untitled')) return;

    try {
      await _ensureTitleSession();
      if (_titleSessionId == null) return;

      _ensureSSEListener();

      _resetState();

      _pendingNotes[noteId] = _PendingTitle(
        noteId: noteId,
        currentPath: currentPath,
      );

      final truncatedContent = content.length > 500 ? content.substring(0, 500) : content;
      final prompt =
          'Generate a short, descriptive filename for this note. '
          'Reply with ONLY the filename, no extension, no quotes, no explanation. '
          'Max 60 characters.\n\n'
          '---\n$truncatedContent';

      await _openCodeClient.sendMessageAsync(
        _titleSessionId!,
        prompt,
        system: 'You are a filename generator. Reply with ONLY a short descriptive filename. '
            'No file extension, no quotes, no explanation, no markdown. Just the filename text.',
      );

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 15), _abortPending);

      debugLogger.info('TITLE', 'Requested title for: $fileName');
    } catch (e) {
      debugLogger.error('TITLE', 'Failed to request title: $e');
      _pendingNotes.remove(noteId);
    }
  }

  Future<void> _ensureTitleSession() async {
    if (_titleSessionId != null) return;

    try {
      final session = await _openCodeClient.createSession();
      _titleSessionId = session.id;
      debugLogger.info('TITLE', 'Created title session: ${session.id}');
    } catch (e) {
      debugLogger.error('TITLE', 'Failed to create session: $e');
    }
  }

  void _ensureSSEListener() {
    if (_sseSubscription != null) return;

    final stream = _sseService.connectToEventStream();
    _sseSubscription = stream.listen(
      _onSSEEvent,
      onError: (e) => debugLogger.error('TITLE', 'SSE error: $e'),
    );
  }

  void _onSSEEvent(OpenCodeEvent event) {
    if (_titleSessionId == null || event.sessionId != _titleSessionId) return;

    if (event.type == 'message.part.updated') {
      _handlePartUpdate(event);
    } else if (event.type == 'session.idle') {
      _handleSessionIdle();
    }
  }

  void _handlePartUpdate(OpenCodeEvent event) {
    final data = event.data;
    if (data == null) return;

    final properties = data['properties'] as Map<String, dynamic>?;
    if (properties == null) return;

    final part = properties['part'] as Map<String, dynamic>?;
    if (part == null) return;

    final partType = part['type'] as String?;
    if (partType != 'text') return;

    final msgId = event.messageId;
    if (msgId == null) return;

    if (_firstMessageId == null) {
      _firstMessageId = msgId;
      return;
    }

    if (msgId == _firstMessageId) return;

    _seenAssistantMessage = true;

    final text = part['text'] as String?;
    final delta = part['delta'] as String?;

    if (text != null) {
      _accumulatedText = text;
    } else if (delta != null) {
      _accumulatedText += delta;
    }
  }

  void _handleSessionIdle() {
    _timeoutTimer?.cancel();

    if (_accumulatedText.isEmpty || _pendingNotes.isEmpty || !_seenAssistantMessage) {
      _resetState();
      _pendingNotes.clear();
      return;
    }

    final title = _cleanTitle(_accumulatedText);
    _resetState();

    if (title.isEmpty) return;

    final lower = title.toLowerCase();
    if (lower.contains('generate') && lower.contains('filename')) {
      debugLogger.error('TITLE', 'Prompt leak detected, aborting');
      _pendingNotes.clear();
      return;
    }

    final entry = _pendingNotes.entries.first;
    final pending = entry.value;
    _pendingNotes.remove(entry.key);
    _completedNotes.add(entry.key);

    _applyTitle(pending, title);
  }

  void _resetState() {
    _accumulatedText = '';
    _firstMessageId = null;
    _seenAssistantMessage = false;
  }

  void _abortPending() {
    debugLogger.error('TITLE', 'Timeout: no valid response, aborting');
    _pendingNotes.clear();
    _resetState();
  }

  String _cleanTitle(String raw) {
    var title = raw.trim();
    title = title.replaceAll(RegExp(r'''^["']|["']$'''), '');
    title = title.replaceAll('.md', '');
    title = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    title = title.replaceAll(RegExp(r'\n.*'), '');
    title = title.trim();
    if (title.length > 60) title = title.substring(0, 60).trim();
    return title;
  }

  Future<void> _applyTitle(_PendingTitle pending, String title) async {
    if (_repo == null) return;

    try {
      final currentPath = pending.currentPath;
      final fileName = currentPath.split('/').last.replaceAll('.md', '');
      if (!fileName.toLowerCase().startsWith('untitled')) {
        debugLogger.info('TITLE', 'Note already renamed, skipping: $fileName');
        return;
      }

      final folderPath = currentPath.contains('/')
          ? currentPath.substring(0, currentPath.lastIndexOf('/') + 1)
          : '';
      final newPath = '$folderPath$title.md';

      if (newPath == currentPath) return;

      debugLogger.info('TITLE', 'AI rename: $fileName -> $title');
      await _repo!.renameNote(pending.noteId, newPath);
    } catch (e) {
      debugLogger.error('TITLE', 'Failed to apply title: $e');
    }
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _sseSubscription?.cancel();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingNotes.clear();
    _completedNotes.clear();
    _noteContents.clear();
    _notePaths.clear();
    _resetState();
  }
}
