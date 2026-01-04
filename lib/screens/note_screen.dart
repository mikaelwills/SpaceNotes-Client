import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../generated/note.dart';
import '../providers/notes_providers.dart';
import '../widgets/quill_note_editor.dart';
import '../widgets/note_bottom_bar.dart';
import '../widgets/note_chat_panel.dart';
import '../blocs/desktop_notes/desktop_notes_bloc.dart';
import '../blocs/desktop_notes/desktop_notes_event.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../services/debug_logger.dart';

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
  final GlobalKey<QuillNoteEditorState> _quillKey = GlobalKey();

  String? _noteId;
  String _currentPath = '';
  String _currentContent = '';
  String _lastSavedContent = '';
  bool _isChatOpen = false;

  late final _repo = ref.read(notesRepositoryProvider);

  Timer? _debounceTimer;
  StreamSubscription<stdb.TableUpdateEvent<Note>>? _updateSubscription;
  StreamSubscription? _clientSubscription;

  @override
  void initState() {
    super.initState();
    _initNote(widget.notePath);
  }

  @override
  void didUpdateWidget(NoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notePath != widget.notePath) {
      _saveContent();
      _initNote(widget.notePath);
    }
  }

  String get _noteName => _currentPath.split('/').last;

  void _initNote(String path) {
    _debounceTimer?.cancel();
    _updateSubscription?.cancel();

    _currentPath = path;
    _noteId = null;

    final note = ref.read(notesListProvider).valueOrNull
        ?.firstWhereOrNull((n) => n.path == path);

    if (note != null) {
      _noteId = note.id;
      _currentContent = note.content;
      _lastSavedContent = note.content;
      debugLogger.info('NOTE', 'Opened: $_noteName (${note.content.length} chars)');
    } else {
      _currentContent = '';
      _lastSavedContent = '';
      debugLogger.info('NOTE', 'Opened new: $_noteName');
    }

    _setupUpdateListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNotePathProvider.notifier).state = path;
      if (mounted) setState(() {});
    });
  }

  void _setupUpdateListener() {
    _updateSubscription?.cancel();
    _updateSubscription = _repo.noteUpdateEvents?.listen((event) {
      if (_noteId == null || event.newRow.id != _noteId) return;

      if (event.context.isMyTransaction) {
        _lastSavedContent = event.newRow.content;
        return;
      }

      if (event.newRow.content != _currentContent) {
        debugLogger.sync('External change detected, syncing');
        _debounceTimer?.cancel();
        _currentContent = event.newRow.content;
        _lastSavedContent = event.newRow.content;
        _quillKey.currentState?.updateContent(event.newRow.content);
        if (mounted) setState(() {});
      }
    });

    _clientSubscription?.cancel();
    _clientSubscription = _repo.watchClient().listen((client) {
      if (client != null && _updateSubscription == null) {
        debugLogger.debug('NOTE', 'Client connected, re-establishing update listener');
        _setupNoteUpdateListener();
      }
    });
  }

  void _setupNoteUpdateListener() {
    _updateSubscription?.cancel();
    _updateSubscription = _repo.noteUpdateEvents?.listen((event) {
      if (_noteId == null || event.newRow.id != _noteId) return;

      if (event.context.isMyTransaction) {
        _lastSavedContent = event.newRow.content;
        return;
      }

      if (event.newRow.content != _currentContent) {
        debugLogger.sync('External change detected, syncing');
        _debounceTimer?.cancel();
        _currentContent = event.newRow.content;
        _lastSavedContent = event.newRow.content;
        _quillKey.currentState?.updateContent(event.newRow.content);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    final hasPending = _currentContent != _lastSavedContent;
    debugLogger.info('NOTE', 'Dispose: $_noteName${hasPending ? " (saving pending)" : ""}');
    _debounceTimer?.cancel();
    _saveContent();
    _updateSubscription?.cancel();
    _clientSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(notesListProvider).valueOrNull
        ?.firstWhereOrNull((n) => _noteId != null ? n.id == _noteId : n.path == _currentPath);

    if (note != null && _noteId == null) {
      _noteId = note.id;
    }

    if (note != null && note.path != _currentPath) {
      _currentPath = note.path;
    }

    final isDesktop = PlatformUtils.isDesktopLayout(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isChatOpen && isDesktop) {
          setState(() => _isChatOpen = false);
          return;
        }
        _saveAndExit();
      },
      child: isDesktop ? _buildDesktopLayout(note) : _buildMobileLayout(note),
    );
  }

  Widget _buildDesktopLayout(Note? note) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: _buildEditor(note),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NoteBottomBar(
                  notePath: _currentPath,
                  quillKey: _quillKey,
                  onChatTap: () => setState(() => _isChatOpen = !_isChatOpen),
                ),
              ),
            ],
          ),
        ),
        if (_isChatOpen)
          NoteChatPanel(
            notePath: _currentPath,
            onClose: () => setState(() => _isChatOpen = false),
            isDesktop: true,
          ),
      ],
    );
  }

  Widget _buildMobileLayout(Note? note) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: _buildEditor(note),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: NoteBottomBar(
            notePath: _currentPath,
            quillKey: _quillKey,
            onChatTap: _openMobileChatSheet,
          ),
        ),
      ],
    );
  }

  void _openMobileChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteChatPanel(
        notePath: _currentPath,
        onClose: () => Navigator.of(context).pop(),
        isDesktop: false,
      ),
    );
  }

  Widget _buildEditor(Note? note) {
    final content = _currentContent.isNotEmpty ? _currentContent : (note?.content ?? '');

    if (_currentContent.isEmpty && note != null) {
      _currentContent = note.content;
      _lastSavedContent = note.content;
    }

    return Listener(
      onPointerMove: (event) {
        if (event.delta.dy > 3) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: QuillNoteEditor(
        key: _quillKey,
        initialContent: content,
        showToolbar: PlatformUtils.isDesktopLayout(context),
        onContentChanged: (markdown) {
          _currentContent = markdown;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(seconds: 1), () {
            debugLogger.debug('NOTE', 'Debounce fired: $_noteName');
            _saveContent();
          });
        },
      ),
    );
  }

  void _saveAndExit() {
    debugLogger.info('NOTE', 'Exit: $_noteName');
    _debounceTimer?.cancel();
    _saveContent();
    _autoRenameIfUntitled();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveContent() async {
    if (_currentContent == _lastSavedContent) return;
    if (_noteId == null) return;

    try {
      debugLogger.save('$_noteName: ${_currentContent.length} chars');
      await _repo.updateNote(_noteId!, _currentContent);
      _lastSavedContent = _currentContent;
    } catch (e) {
      debugLogger.error('SAVE', '$_noteName failed: $e');
    }
  }

  Future<void> _autoRenameIfUntitled() async {
    if (_noteId == null) return;

    final fileName = _currentPath.split('/').last.replaceAll('.md', '');
    if (!fileName.toLowerCase().contains('untitled')) return;

    final firstLine = _currentContent
        .split('\n')
        .map((l) => l.trim())
        .firstWhereOrNull((l) => l.isNotEmpty && l != '#');

    if (firstLine == null) return;

    var newName = firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
    if (newName.isEmpty) {
      newName = _currentContent.replaceAll('\n', ' ').replaceAll(RegExp(r'^#+\s*'), '').trim();
      if (newName.length > 50) newName = newName.substring(0, 50);
    }

    if (newName.isEmpty || newName.toLowerCase() == 'untitled') return;

    newName = newName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    final folderPath = _currentPath.contains('/')
        ? _currentPath.substring(0, _currentPath.lastIndexOf('/') + 1)
        : '';
    final newPath = '$folderPath$newName.md';

    if (newPath == _currentPath) return;

    debugLogger.save('Auto-rename: $newPath');
    final success = await _repo.renameNote(_noteId!, newPath);

    if (success && mounted) {
      final oldPath = _currentPath;
      _currentPath = newPath;
      context.read<DesktopNotesBloc?>()?.add(UpdateNotePath(oldPath, newPath));
    }
  }
}
