import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import 'package:go_router/go_router.dart';
import '../generated/note.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/notes_providers.dart';
import '../widgets/markdown_styles.dart';
import '../dialogs/notes_list_dialogs.dart';

// Data structure for editable markdown chunks
class MarkdownChunk {
  final String id; // UUID to track chunks across re-parses
  final int startOffset;
  final int endOffset;
  final String content;
  final ChunkType type;

  MarkdownChunk({
    required this.id,
    required this.startOffset,
    required this.endOffset,
    required this.content,
    required this.type,
  });

  String get rawText => content;
  int get length => endOffset - startOffset;

  MarkdownChunk copyWith({
    String? id,
    int? startOffset,
    int? endOffset,
    String? content,
    ChunkType? type,
  }) {
    return MarkdownChunk(
      id: id ?? this.id,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      content: content ?? this.content,
      type: type ?? this.type,
    );
  }
}

enum ChunkType { paragraph, header, list, codeBlock, blockquote }

class NoteScreen extends ConsumerStatefulWidget {
  final String notePath;
  final bool isNewNote;

  const NoteScreen({
    super.key,
    required this.notePath,
    this.isNewNote = false,
  });

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  // 1. CONSTRUCTOR - State variables
  late TextEditingController _contentController;
  late FocusNode _focusNode;

  String _lastSavedContent = '';
  bool _isLocalChange = false;
  bool _isEditing = false;
  String? _noteId; // Store the note's UUID

  // Dynamic filename tracking
  String _currentPath = ''; // Display path (updated optimistically)
  String _savedPath = ''; // Last path known to server (for updates)

  Timer? _debounceTimer;

  // Subscription to note update events for isMyTransaction checking
  StreamSubscription<stdb.TableUpdateEvent<Note>>? _updateEventSubscription;

  // Chunk preview state (for markdown rendering only, not editing)
  List<MarkdownChunk> _chunks = []; // Parsed document chunks
  String _lastParsedContent = ''; // Track when content changed to re-parse

  // 2. INIT
  @override
  void initState() {
    super.initState();
    _currentPath = widget.notePath;

    _contentController = TextEditingController();
    _contentController.addListener(_onContentChanged);

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    if (widget.isNewNote) {
      // Start with just "# " so user types the title directly
      _contentController.text = '# \n';
      _lastSavedContent = '# \n';
      // Position cursor after "# "
      _contentController.selection = const TextSelection.collapsed(offset: 2);
      _isEditing = true;
      _savedPath = _currentPath;
      // Create note immediately on server
      _createNoteImmediately();
    } else {
      // For existing notes, look up the ID from cached data
      final notes = ref.read(notesListProvider).valueOrNull;
      final existingNote =
          notes?.firstWhereOrNull((n) => n.path == _currentPath);
      if (existingNote != null) {
        _noteId = existingNote.id;
        _savedPath = _currentPath;
      }
    }

    // Subscribe to update events
    _setupUpdateEventListener();
  }

  void _setupUpdateEventListener() {
    final repo = ref.read(notesRepositoryProvider);
    _updateEventSubscription = repo.noteUpdateEvents?.listen((event) {
      // Only care about updates to THIS note
      if (_noteId == null || event.newRow.id != _noteId) return;

      final isMyChange = event.context.isMyTransaction;

      if (isMyChange) {
        // My echo - update _lastSavedContent to match what server has
        _lastSavedContent = event.newRow.content;
        return;
      }

      // External change from another user/client
      debugPrint('⚠️ External change detected for ${event.newRow.path}');

      if (_focusNode.hasFocus) {
        // User is typing - don't overwrite their work
        // TODO: Snackbar disabled - isMyTransaction returning false for own changes
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //       content: Text('Note was modified by another device'),
        //       duration: Duration(seconds: 3),
        //     ),
        //   );
        // }
        return;
      }

      // User not editing - safe to sync
      if (event.newRow.content != _contentController.text) {
        debugPrint('📡 Syncing external change');
        _updateControllerSilently(event.newRow.content);
        if (mounted) setState(() {});
      }
    });
  }


  Future<void> _createNoteImmediately() async {
    final repo = ref.read(notesRepositoryProvider);
    try {
      final id = await repo.createNote(_savedPath, _contentController.text);
      if (mounted && id != null) {
        _noteId = id;
        debugPrint('✅ CREATE: ID=$id | path=$_savedPath');
        // Save any content typed while waiting for ID
        if (_contentController.text != _lastSavedContent) {
          _saveContent();
        }
      }
    } catch (e) {
      debugPrint('❌ CREATE FAILED: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _updateEventSubscription?.cancel();

    // No more chunk controllers to dispose

    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 3. BUILD
  @override
  Widget build(BuildContext context) {
    // 1. Select the specific note data by ID (not path - path can change!)
    final noteSelector = notesListProvider.select((value) => value.whenData(
        (notes) => _noteId != null
            ? notes.firstWhereOrNull((n) => n.id == _noteId)
            : notes.firstWhereOrNull((n) => n.path == _currentPath)));

    final noteAsync = ref.watch(noteSelector);
    final currentNote = noteAsync.valueOrNull;

    // 2. Listen for state changes (ID assignment, path updates, and deletion)
    ref.listen<AsyncValue<Note?>>(noteSelector, (previous, next) {
      next.whenData((remoteNote) {
        if (remoteNote != null) {
          _noteId ??= remoteNote.id;

          // Update current path if it changed (from rename)
          if (remoteNote.path != _currentPath) {
            _currentPath = remoteNote.path;
            _savedPath = remoteNote.path;
          }
        } else if (_noteId != null && mounted) {
          // Note was deleted (selector returns null because ID no longer exists)
          // Navigation is handled by the delete dialog, so we don't navigate here
          debugPrint('🗑️ Note deleted (navigation handled by delete dialog)');
        }
      });
    });

    // 3. Controller Synchronization Logic
    // If we have data from server, but controller is empty, sync it up.
    if (!widget.isNewNote &&
        currentNote != null &&
        _contentController.text.isEmpty &&
        !_isLocalChange) {
      // We use PostFrameCallback to safely update controller state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _contentController.text.isEmpty) {
          _updateControllerSilently(currentNote.content);
          // Force a rebuild so the Preview catches up if it was showing placeholder
          setState(() {});
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _forceSave();
        if (mounted) Navigator.of(context).pop();
      },
      child: Column(
        children: [
          Expanded(
            child: _isEditing ? _buildEditor() : _buildHybridView(currentNote),
          ),
          _buildBottomActionBar(currentNote),
        ],
      ),
    );
  }

  // 4. WIDGET FUNCTIONS
  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      focusNode: _focusNode,
      autofocus: true, // Auto-focus when entering edit mode
      style: const TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 14,
        color: SpaceNotesTheme.text,
        height: 1.6,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
        hintText: 'Start writing...',
        hintStyle: TextStyle(color: SpaceNotesTheme.textSecondary),
      ),
    );
  }

  Widget _buildHybridView(Note? currentNote) {
    // Determine what text to show
    String textToShow = _contentController.text;
    if (textToShow.isEmpty && currentNote != null) {
      textToShow = currentNote.content;
    }

    // Parse content into chunks if needed
    if (_chunks.isEmpty || textToShow != _lastParsedContent) {
      _chunks = _parseIntoChunks(textToShow);
      _lastParsedContent = textToShow;
    }

    return GestureDetector(
      onTap: () {
        // Tapping background enters full edit mode at end of document
        if (textToShow.isEmpty && currentNote != null) {
          _updateControllerSilently(currentNote.content);
        }
        setState(() => _isEditing = true);

        // Position cursor at end of document
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _contentController.selection = TextSelection.collapsed(
              offset: _contentController.text.length,
            );
            _focusNode.requestFocus();
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: _chunks.isEmpty && textToShow.isEmpty
              ? const Text(
                  'Tap to start writing...',
                  style: TextStyle(color: SpaceNotesTheme.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _chunks.length; i++)
                      _buildChunkWidget(_chunks[i]),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChunkWidget(MarkdownChunk chunk) {
    return _buildChunkPreview(chunk);
  }

  Widget _buildChunkPreview(MarkdownChunk chunk) {
    // Empty line chunks should have no padding to match editor line height
    final isEmptyLine = chunk.content.trim().isEmpty;

    // For empty lines, render actual spacing instead of markdown
    if (isEmptyLine) {
      return GestureDetector(
        onTap: () => _navigateToChunk(chunk),
        child: const SizedBox(
          width: double.infinity,
          height: 22.4, // Match editor line height (fontSize 14 * height 1.6)
        ),
      );
    }

    return GestureDetector(
      onTap: () => _navigateToChunk(chunk),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: MarkdownBody(
          data: chunk.content,
          styleSheet: OpenCodeMarkdownStyles.standard,
          softLineBreak: true,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(Note? currentNote) {
    if (currentNote == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 56,
      color: SpaceNotesTheme.background,
      child: Row(
        children: [
          // Back button (left side)
          IconButton(
            onPressed: _navigateBackFromNote,
            tooltip: 'Back',
            icon: const Icon(
              size: 30,
              Icons.arrow_back,
              color: SpaceNotesTheme.primary,
            ),
          ),
          const Spacer(), // Push action buttons to the right
          Expanded(
            child: Material(
              color: SpaceNotesTheme.background,
              child: InkWell(
                onTap: () => _handleMoveNote(currentNote),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.drive_file_move_outlined,
                      color: SpaceNotesTheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Move',
                      style: TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: SpaceNotesTheme.background,
              child: InkWell(
                onTap: () => _handleDeleteNote(currentNote),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: SpaceNotesTheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: SpaceNotesTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. HELPER FUNCTIONS
  void _updateControllerSilently(String newText) {
    _contentController.removeListener(_onContentChanged);
    _contentController.text = newText;
    _lastSavedContent = newText;
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    _isLocalChange = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _saveContent();
    });
  }


  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _forceSave();
      _isLocalChange = false;
    } else {
      _isLocalChange = true;
    }
  }

  void _forceSave() {
    _debounceTimer?.cancel();
    _saveContent();
    _autoRenameIfUntitled();
  }

  Future<void> _autoRenameIfUntitled() async {
    if (_noteId == null) return;

    final fileName = _currentPath.split('/').last.replaceAll('.md', '');

    if (!fileName.toLowerCase().contains('untitled')) {
      return;
    }

    final content = _contentController.text.trim();

    if (content.isEmpty || content == '#' || content == '# \n') {
      return;
    }

    final firstLine = content.split('\n').first.trim();
    String newName = firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();

    if (newName.isEmpty) {
      newName = content.replaceAll('\n', ' ').trim();
      if (newName.length > 50) {
        newName = newName.substring(0, 50);
      }
    }

    if (newName.isEmpty || newName.toLowerCase() == 'untitled') {
      return;
    }

    newName = newName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    final folderPath = _currentPath.contains('/')
        ? _currentPath.substring(0, _currentPath.lastIndexOf('/') + 1)
        : '';

    final newPath = '$folderPath$newName.md';

    if (newPath == _currentPath) return;

    final repo = ref.read(notesRepositoryProvider);
    debugPrint('🏷️  AUTO-RENAME from Untitled: $newPath');
    final success = await repo.renameNote(_noteId!, newPath);

    if (success && mounted) {
      setState(() {
        _currentPath = newPath;
        _savedPath = newPath;
      });
    }
  }

  Future<void> _saveContent() async {
    final currentText = _contentController.text;
    if (currentText == _lastSavedContent) return;

    // Can't save if we don't have the note ID yet
    if (_noteId == null) {
      return;
    }

    final repo = ref.read(notesRepositoryProvider);

    try {
      debugPrint('📝 CONTENT UPDATE: ${currentText.length} chars');
      await repo.updateNote(_noteId!, currentText);
      _lastSavedContent = currentText;
    } catch (e) {
      debugPrint('❌ Content save failed: $e');
    }
  }

  void _navigateToChunk(MarkdownChunk chunk) {
    // Step 1: Enter full editor mode
    setState(() {
      _isEditing = true;
    });

    // Step 2: Position cursor at chunk's start offset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Set cursor position to start of chunk
        _contentController.selection = TextSelection.collapsed(
          offset: chunk.startOffset,
        );

        // Request focus to show keyboard
        _focusNode.requestFocus();
      }
    });
  }


  // CHUNK PARSING METHODS

  /// Parse document content into editable chunks
  List<MarkdownChunk> _parseIntoChunks(String content) {
    final chunks = <MarkdownChunk>[];
    final lines = content.split('\n');

    int currentOffset = 0;
    int chunkStart = 0;
    String chunkBuffer = '';
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Track code block state
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
      }

      // Detect chunk boundaries (empty lines, type changes, code block boundaries)
      final isEmptyLine = line.trim().isEmpty;
      final isLastLine = i == lines.length - 1;
      final isCodeBlockBoundary = line.trim().startsWith('```') && !inCodeBlock;

      if ((isEmptyLine && !inCodeBlock) || isLastLine || isCodeBlockBoundary) {
        // End current chunk
        if (!isEmptyLine) chunkBuffer += line;
        if (isCodeBlockBoundary && !isEmptyLine) chunkBuffer += '\n';

        if (chunkBuffer.isNotEmpty) {
          chunks.add(MarkdownChunk(
            id: _generateChunkId(),
            startOffset: chunkStart,
            endOffset:
                currentOffset + (isLastLine && !isEmptyLine ? line.length : 0),
            content: chunkBuffer,
            type: _detectChunkType(chunkBuffer),
          ));
        }

        // Add empty line as a spacing chunk (preserves vertical spacing)
        if (isEmptyLine && !isLastLine) {
          chunks.add(MarkdownChunk(
            id: _generateChunkId(),
            startOffset: currentOffset,
            endOffset: currentOffset + 1,
            content: '\n',
            type: ChunkType.paragraph,
          ));
        }

        // Start new chunk
        chunkStart = currentOffset + line.length + 1;
        chunkBuffer = '';
      } else {
        chunkBuffer += '$line\n';
      }

      currentOffset += line.length + 1;
    }

    return chunks;
  }

  /// Generate unique ID for chunks
  String _generateChunkId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
  }

  /// Detect the type of markdown chunk
  ChunkType _detectChunkType(String content) {
    final firstLine = content.trim().split('\n').first;
    if (firstLine.startsWith('#')) return ChunkType.header;
    if (firstLine.startsWith('```')) return ChunkType.codeBlock;
    if (firstLine.startsWith('-') ||
        firstLine.startsWith('*') ||
        firstLine.startsWith('+') ||
        RegExp(r'^\d+\.\s').hasMatch(firstLine)) {
      return ChunkType.list;
    }
    if (firstLine.startsWith('>')) return ChunkType.blockquote;
    return ChunkType.paragraph;
  }

  void _handleMoveNote(Note note) {
    NotesListDialogs.showMoveNoteDialog(context, ref, note);
  }

  void _navigateBackFromNote() {
    final notePath = widget.notePath;
    final lastSlash = notePath.lastIndexOf('/');

    if (lastSlash == -1) {
      // Note is in root, go to /notes
      context.go('/notes');
    } else {
      // Note is in a folder, go to that folder
      final folderPath = notePath.substring(0, lastSlash);
      final encodedFolderPath = Uri.encodeComponent(folderPath);
      context.go('/notes/folder/$encodedFolderPath');
    }
  }

  void _handleDeleteNote(Note note) {
    // Calculate where to navigate after delete
    final notePath = note.path;
    final String navigateTo;

    if (notePath.contains('/')) {
      // Note is in a folder - navigate back to that folder
      final lastSlash = notePath.lastIndexOf('/');
      final folderPath = notePath.substring(0, lastSlash);
      final encodedFolderPath = Uri.encodeComponent(folderPath);
      navigateTo = '/notes/folder/$encodedFolderPath';
    } else {
      // Note is at root - navigate to notes root
      navigateTo = '/notes';
    }

    NotesListDialogs.showDeleteNoteConfirmation(
      context,
      ref,
      note,
      navigateToAfterDelete: navigateTo,
    );
  }

}
