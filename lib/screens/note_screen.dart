import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../generated/note.dart';
import '../providers/notes_providers.dart';
import '../widgets/quill_note_editor.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../widgets/adaptive/platform_utils.dart';
import 'home_screen.dart';

class NoteScreen extends ConsumerStatefulWidget {
  final String notePath;

  const NoteScreen({
    super.key,
    required this.notePath,
  });

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final GlobalKey<QuillNoteEditorState> _quillKey = GlobalKey<QuillNoteEditorState>();

  String _lastSavedContent = '';
  bool _isLocalChange = false;
  bool _quillInitialized = false;
  String? _noteId;
  String _currentPath = '';
  String _currentContent = '';

  Timer? _debounceTimer;
  StreamSubscription<stdb.TableUpdateEvent<Note>>? _updateEventSubscription;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.notePath;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNotePathProvider.notifier).state = widget.notePath;
    });

    final notes = ref.read(notesListProvider).valueOrNull;
    final existingNote = notes?.firstWhereOrNull((n) => n.path == _currentPath);
    if (existingNote != null) {
      _noteId = existingNote.id;
      _currentContent = existingNote.content;
      _lastSavedContent = existingNote.content;
    }

    _setupUpdateEventListener();
  }

  @override
  void didUpdateWidget(NoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notePath != widget.notePath) {
      _loadNewNote();
    }
  }

  void _loadNewNote() {
    _debounceTimer?.cancel();
    _updateEventSubscription?.cancel();

    _currentPath = widget.notePath;
    _quillInitialized = false;
    _noteId = null;

    Future(() {
      ref.read(currentNotePathProvider.notifier).state = widget.notePath;
    });

    final notes = ref.read(notesListProvider).valueOrNull;
    final existingNote = notes?.firstWhereOrNull((n) => n.path == _currentPath);
    if (existingNote != null) {
      _noteId = existingNote.id;
      _currentContent = existingNote.content;
      _lastSavedContent = existingNote.content;
    } else {
      _currentContent = '';
      _lastSavedContent = '';
    }

    _setupUpdateEventListener();
    setState(() {});
  }

  void _setupUpdateEventListener() {
    final repo = ref.read(notesRepositoryProvider);
    _updateEventSubscription = repo.noteUpdateEvents?.listen((event) {
      if (_noteId == null || event.newRow.id != _noteId) return;

      final isMyChange = event.context.isMyTransaction;

      if (isMyChange) {
        _lastSavedContent = event.newRow.content;
        return;
      }

      debugPrint('⚠️ External change detected for ${event.newRow.path}');

      if (event.newRow.content != _currentContent) {
        debugPrint('📡 Syncing external change');
        _currentContent = event.newRow.content;
        _quillKey.currentState?.updateContent(event.newRow.content);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _updateEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteSelector = notesListProvider.select((value) => value.whenData(
        (notes) => _noteId != null
            ? notes.firstWhereOrNull((n) => n.id == _noteId)
            : notes.firstWhereOrNull((n) => n.path == _currentPath)));

    final noteAsync = ref.watch(noteSelector);
    final currentNote = noteAsync.valueOrNull;

    ref.listen<AsyncValue<Note?>>(noteSelector, (previous, next) {
      next.whenData((remoteNote) {
        if (remoteNote != null) {
          _noteId ??= remoteNote.id;

          if (remoteNote.path != _currentPath) {
            _currentPath = remoteNote.path;
          }
        } else if (_noteId != null && mounted) {
          debugPrint('🗑️ Note deleted (navigation handled by delete dialog)');
        }
      });
    });

    if (currentNote != null && _currentContent.isEmpty && !_isLocalChange && !_quillInitialized) {
      _currentContent = currentNote.content;
      _lastSavedContent = currentNote.content;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _forceSave();
        if (mounted) Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: _buildQuillEditor(currentNote),
      ),
    );
  }

  Widget _buildQuillEditor(Note? currentNote) {
    String initialContent = _currentContent;
    if (initialContent.isEmpty && currentNote != null) {
      initialContent = currentNote.content;
      if (!_quillInitialized) {
        _currentContent = initialContent;
        _lastSavedContent = initialContent;
        _quillInitialized = true;
      }
    }

    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return Listener(
      onPointerMove: (event) {
        if (event.delta.dy > 3) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: QuillNoteEditor(
        key: _quillKey,
        initialContent: initialContent,
        showToolbar: isDesktop,
        onContentChanged: (markdown) {
          _isLocalChange = true;
          _currentContent = markdown;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            _saveContent();
          });
        },
      ),
    );
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

    final rawContent = _currentContent;
    final lines = rawContent.split('\n');
    String? firstMeaningfulLine;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        firstMeaningfulLine = trimmed;
        break;
      }
    }

    if (firstMeaningfulLine == null || firstMeaningfulLine == '#') {
      return;
    }

    String newName = firstMeaningfulLine.replaceAll(RegExp(r'^#+\s*'), '').trim();

    if (newName.isEmpty) {
      final contentFlat = rawContent.replaceAll('\n', ' ').trim();
      newName = contentFlat.replaceAll(RegExp(r'^#+\s*'), '').trim();
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
      final oldPath = _currentPath;
      setState(() {
        _currentPath = newPath;
      });
      context.read<DesktopNotesBloc?>()?.add(UpdateNotePath(oldPath, newPath));
    }
  }

  Future<void> _saveContent() async {
    final currentText = _currentContent;
    if (currentText == _lastSavedContent) return;

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
}
