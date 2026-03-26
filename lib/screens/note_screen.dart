import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../generated/note.dart';
import '../providers/notes_providers.dart';
import '../widgets/quill_note_editor.dart';
import '../widgets/note_bottom_bar.dart';
import '../widgets/note_chat_panel.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../services/debug_logger.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';

class NoteScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteScreen({
    super.key,
    required this.noteId,
  });

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final GlobalKey<QuillNoteEditorState> _quillKey = GlobalKey();

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
    _initNote();
  }

  @override
  void didUpdateWidget(NoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _saveContent();
      _initNote();
    }
  }

  @override
  void dispose() {
    final hasPending = _currentContent != _lastSavedContent;
    debugLogger.info('NOTE', 'Dispose: $_noteName${hasPending ? " (saving pending)" : ""}');
    _debounceTimer?.cancel();
    _saveContent();
    final fileName = _currentPath.split('/').last.replaceAll('.md', '');
    if (fileName.toLowerCase().startsWith('untitled') && _currentContent.length >= 10) {
      debugLogger.info('NOTE', 'Dispose trigger: requesting title for $fileName');
      _repo.titleService?.triggerImmediate(
        widget.noteId,
        content: _currentContent,
        path: _currentPath,
      );
    }
    _updateSubscription?.cancel();
    _clientSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(notesListProvider).valueOrNull
        ?.firstWhereOrNull((n) => n.id == widget.noteId);

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
        await _saveAndExit();
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
                  onChatTap: () => setState(() {
                    _isChatOpen = !_isChatOpen;
                  }),
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

  Widget _buildEditor(Note? note) {
    final content = _currentContent.isNotEmpty ? _currentContent : (note?.content ?? '');

    if (_currentContent.isEmpty && note != null) {
      _currentContent = note.content;
      _lastSavedContent = note.content;
    }

    return KeyboardDismissOnScroll(
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

  String get _noteName => _currentPath.split('/').last;

  void _initNote() {
    _debounceTimer?.cancel();
    _updateSubscription?.cancel();

    final note = ref.read(notesListProvider).valueOrNull
        ?.firstWhereOrNull((n) => n.id == widget.noteId);

    if (note != null) {
      _currentPath = note.path;
      _currentContent = note.content;
      _lastSavedContent = note.content;
      debugLogger.info('NOTE', 'Opened: $_noteName (${note.content.length} chars)');
    } else {
      _currentPath = '';
      _currentContent = '';
      _lastSavedContent = '';
      debugLogger.info('NOTE', 'Note not found: ${widget.noteId}');
    }

    _setupUpdateListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNotePathProvider.notifier).state = _currentPath;
      if (mounted) setState(() {});
    });
  }

  void _setupUpdateListener() {
    _updateSubscription?.cancel();
    _updateSubscription = _repo.noteUpdateEvents?.listen((event) {
      if (event.newRow.id != widget.noteId) return;

      if (event.newRow.path != _currentPath) {
        _currentPath = event.newRow.path;
        ref.read(currentNotePathProvider.notifier).state = _currentPath;
      }

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
      if (event.newRow.id != widget.noteId) return;

      if (event.newRow.path != _currentPath) {
        _currentPath = event.newRow.path;
        ref.read(currentNotePathProvider.notifier).state = _currentPath;
      }

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

  void _openMobileChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (context) => NoteChatPanel(
        notePath: _currentPath,
        onClose: () => Navigator.of(context).pop(),
        isDesktop: false,
      ),
    );
  }

  Future<void> _saveAndExit() async {
    debugLogger.info('NOTE', 'Exit: $_noteName');
    _debounceTimer?.cancel();
    await _saveContent();
    final fileName = _currentPath.split('/').last.replaceAll('.md', '');
    if (fileName.toLowerCase().startsWith('untitled')) {
      _repo.titleService?.triggerImmediate(
        widget.noteId,
        content: _currentContent,
        path: _currentPath,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveContent() async {
    if (_currentContent == _lastSavedContent) return;

    try {
      debugLogger.save('$_noteName: ${_currentContent.length} chars');
      await _repo.updateNote(widget.noteId, _currentContent);
      _lastSavedContent = _currentContent;
    } catch (e) {
      debugLogger.error('SAVE', '$_noteName failed: $e');
    }
  }

}
