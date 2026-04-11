import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/client.dart';
import '../generated/note.dart';
import '../providers/notes_providers.dart';
import '../widgets/quill_note_editor.dart';
import '../widgets/note_bottom_bar.dart';
import '../widgets/note_chat_panel.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../services/debug_logger.dart';
import '../widgets/keyboard_dismiss_on_scroll.dart';
import '../theme/spacenotes_theme.dart';
import 'chat_view.dart';

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
  double _chatHeight = 0;

  late final _repo = ref.read(notesRepositoryProvider);

  Timer? _debounceTimer;
  SpacetimeDbClient? _listenedClient;
  VoidCallback? _batchListener;

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
    debugLogger.info(
        'NOTE', 'Dispose: $_noteName${hasPending ? " (saving pending)" : ""}');
    _debounceTimer?.cancel();
    _saveContent();
    final fileName = _currentPath.split('/').last.replaceAll('.md', '');
    if (fileName.toLowerCase().startsWith('untitled') &&
        _currentContent.length >= 10) {
      debugLogger.info(
          'NOTE', 'Dispose trigger: requesting title for $fileName');
      _repo.titleService?.triggerImmediate(
        widget.noteId,
        content: _currentContent,
        path: _currentPath,
      );
    }
    _detachBatchListener();
    _repo.clientNotifier.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref
        .watch(notesListProvider)
        .firstWhereOrNull((n) => n.id == widget.noteId);

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
    return Column(
      children: [
        Expanded(
          child: _buildEditor(note),
        ),
        if (_isChatOpen) _buildMobileChatArea(),
        NoteBottomBar(
          notePath: _currentPath,
          quillKey: _quillKey,
          onChatTap: () => setState(() {
            _isChatOpen = !_isChatOpen;
          }),
          onSendMessage: () {
            if (!_isChatOpen) {
              setState(() => _isChatOpen = true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMobileChatArea() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _chatHeight -= details.delta.dy;
          _chatHeight =
              _chatHeight.clamp(100, MediaQuery.of(context).size.height * 0.6);
        });
      },
      onVerticalDragEnd: (details) {
        if (_chatHeight < 150 || details.primaryVelocity! > 300) {
          setState(() {
            _isChatOpen = false;
            _chatHeight = 0;
          });
        }
      },
      child: Container(
        height: _chatHeight > 0
            ? _chatHeight
            : MediaQuery.of(context).size.height * 0.35,
        decoration: const BoxDecoration(
          color: SpaceNotesTheme.background,
          border: Border(
            top: BorderSide(color: SpaceNotesTheme.inputSurface, width: 1),
          ),
        ),
        child: Column(
          children: [
            _buildChatDragHandle(),
            const Expanded(
              child: ChatView(
                showConnectionStatus: false,
                showInput: false,
                messagePadding: EdgeInsets.fromLTRB(8, 4, 8, 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDragHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEditor(Note? note) {
    final content =
        _currentContent.isNotEmpty ? _currentContent : (note?.content ?? '');

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

    final note = ref
        .read(notesListProvider)
        .firstWhereOrNull((n) => n.id == widget.noteId);

    if (note != null) {
      _currentPath = note.path;
      _currentContent = note.content;
      _lastSavedContent = note.content;
      debugLogger.info(
          'NOTE', 'Opened: $_noteName (${note.content.length} chars)');
    } else {
      _currentPath = '';
      _currentContent = '';
      _lastSavedContent = '';
      debugLogger.info('NOTE', 'Note not found: ${widget.noteId}');
    }

    _attachToCurrentClient();
    _repo.clientNotifier.removeListener(_onClientChanged);
    _repo.clientNotifier.addListener(_onClientChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNotePathProvider.notifier).state = _currentPath;
      if (mounted) setState(() {});
    });
  }

  void _onClientChanged() {
    if (!mounted) return;
    debugLogger.debug('NOTE', 'Client changed, rewiring batch listener');
    _attachToCurrentClient();
  }

  void _attachToCurrentClient() {
    final client = _repo.client;
    if (identical(client, _listenedClient)) return;

    _detachBatchListener();
    _listenedClient = client;

    if (client == null) return;

    final notifier = client.note.lastBatch;
    void listener() {
      final batch = notifier.value;
      if (batch == null) return;
      _handleNoteBatch(batch);
    }

    notifier.addListener(listener);
    _batchListener = listener;
  }

  void _detachBatchListener() {
    final client = _listenedClient;
    final listener = _batchListener;
    if (client != null && listener != null) {
      client.note.lastBatch.removeListener(listener);
    }
    _batchListener = null;
    _listenedClient = null;
  }

  void _handleNoteBatch(TransactionBatch<Note> batch) {
    for (final event in batch.updates) {
      if (event.newRow.id != widget.noteId) continue;

      debugLogger.info(
        'SYNC_DEBUG',
        'NoteScreen update',
        'isMyTransaction=${event.context.isMyTransaction}, isOptimistic=${event.context.isOptimistic}, contentChanged=${event.newRow.content != _currentContent}, name=${event.newRow.name}',
      );

      if (event.newRow.path != _currentPath) {
        _currentPath = event.newRow.path;
        ref.read(currentNotePathProvider.notifier).state = _currentPath;
      }

      if (event.context.isMyTransaction) {
        debugLogger.info('SYNC_DEBUG', 'Dropped as local echo');
        _lastSavedContent = event.newRow.content;
        return;
      }

      if (event.newRow.content != _currentContent) {
        debugLogger.info('SYNC_DEBUG', 'Applying external update to editor');
        _debounceTimer?.cancel();
        _currentContent = event.newRow.content;
        _lastSavedContent = event.newRow.content;
        _quillKey.currentState?.updateContent(event.newRow.content);
        if (mounted) setState(() {});
      } else {
        debugLogger.info('SYNC_DEBUG', 'Content identical, skipping');
      }
      return;
    }
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
