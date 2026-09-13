import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';
import '../generated/client.dart';
import '../generated/file_content.dart';
import '../generated/space_file.dart';
import '../providers/notes_providers.dart';
import '../services/genui_note_parser.dart';
import '../widgets/audio_mini_bar.dart';
import '../widgets/dashboard/genui_surface.dart';
import '../widgets/quill_note_editor.dart';
import '../widgets/note_status_bar.dart';
import '../widgets/note_bottom_bar.dart';
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
  bool _contentLoaded = false;
  bool _isChatOpen = false;
  double _chatHeight = 0;

  late final _repo = ref.read(notesRepositoryProvider);

  Timer? _debounceTimer;
  SpacetimeDbClient? _listenedClient;
  StreamSubscription<TableInsertEvent<FileContent>>? _contentInsertSubscription;
  StreamSubscription<TableUpdateEvent<FileContent>>? _contentUpdateSubscription;
  StreamSubscription<TableUpdateEvent<SpaceFile>>? _pathSubscription;

  @override
  void initState() {
    super.initState();
    _initNote();
  }

  @override
  void didUpdateWidget(NoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _saveContent(noteId: oldWidget.noteId);
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
    _detachSubscriptions();
    _repo.clientNotifier.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(fileByIdProvider(widget.noteId));
    final content = ref.watch(noteContentProvider(widget.noteId));
    final hydrated = ref
        .watch(noteContentHydratedProvider(widget.noteId))
        .maybeWhen(data: (v) => v, orElse: () => false);

    if (note != null && note.path != _currentPath) {
      _currentPath = note.path;
    }

    if (content != null && !_contentLoaded) {
      _seedContent(content);
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
      child: isDesktop
          ? _buildDesktopLayout(note, content, hydrated)
          : _buildMobileLayout(note, content, hydrated),
    );
  }

  Widget _buildDesktopLayout(SpaceFile? note, String? content, bool hydrated) {
    return Stack(
      children: [
        Column(
          children: [
            if (note != null)
              NoteStatusBar(note: note, contentHydrated: hydrated),
            Expanded(child: _buildEditor(content)),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: NoteBottomBar(
            notePath: _currentPath,
            quillKey: _quillKey,
            onChatTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(SpaceFile? note, String? content, bool hydrated) {
    return Column(
      children: [
        if (note != null) NoteStatusBar(note: note, contentHydrated: hydrated),
        Expanded(
          child: _buildEditor(content),
        ),
        if (_isChatOpen) _buildMobileChatArea(),
        const AudioMiniBar(),
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

  /// No editor exists until the body is known. The editor autosaves, so an
  /// editor seeded with '' during the gap before the body arrives would write
  /// that '' over the real note; not building it is what rules that out.
  Widget _buildEditor(String? content) {
    if (content == null) return const SizedBox.shrink();

    if (GenuiNoteParser.parse(_currentContent) != null) {
      return GenuiSurface(
        body: _currentContent,
        onBodyChanged: (newBody) {
          _currentContent = newBody;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(seconds: 1), () {
            debugLogger.debug('NOTE', 'Debounce fired (genui): $_noteName');
            _saveContent();
          });
        },
      );
    }

    return KeyboardDismissOnScroll(
      child: QuillNoteEditor(
        key: _quillKey,
        initialContent: _currentContent,
        showToolbar: PlatformUtils.isDesktopLayout(context),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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

  void _seedContent(String content) {
    _contentLoaded = true;
    _currentContent = content;
    _lastSavedContent = content;
    debugLogger.info('NOTE', 'Opened: $_noteName (${content.length} chars)');
  }

  void _initNote() {
    _debounceTimer?.cancel();
    _contentLoaded = false;
    _currentContent = '';
    _lastSavedContent = '';

    final note = ref.read(fileByIdProvider(widget.noteId));

    if (note != null) {
      _currentPath = note.path;
    } else {
      _currentPath = '';
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
    debugLogger.debug('NOTE', 'Client changed, rewiring subscriptions');
    _attachToCurrentClient();
  }

  void _attachToCurrentClient() {
    final client = _repo.notesClient;
    if (identical(client, _listenedClient)) return;

    _detachSubscriptions();
    _listenedClient = client;

    if (client == null) return;

    _pathSubscription = client.spaceFile.onUpdate.listen((event) {
      if (event.newRow.id != widget.noteId) return;
      if (event.newRow.path == _currentPath) return;
      _currentPath = event.newRow.path;
      ref.read(currentNotePathProvider.notifier).state = _currentPath;
    });

    _contentInsertSubscription = client.fileContent.onInsert.listen((event) {
      if (event.row.fileId != widget.noteId) return;
      _applyRemoteContent(event.row.content, event.context);
    });

    _contentUpdateSubscription = client.fileContent.onUpdate.listen((event) {
      if (event.newRow.fileId != widget.noteId) return;
      _applyRemoteContent(event.newRow.content, event.context);
    });
  }

  void _applyRemoteContent(String content, EventContext context) {
    debugLogger.info(
      'SYNC_DEBUG',
      'NoteScreen content event',
      'isMyTransaction=${context.isMyTransaction}, isOptimistic=${context.isOptimistic}, contentChanged=${content != _currentContent}',
    );

    if (context.isMyTransaction) {
      debugLogger.info('SYNC_DEBUG', 'Dropped as local echo');
      _lastSavedContent = content;
      return;
    }

    if (content == _currentContent) {
      debugLogger.info('SYNC_DEBUG', 'Content identical, skipping');
      return;
    }

    debugLogger.info('SYNC_DEBUG', 'Applying external update to editor');
    _debounceTimer?.cancel();
    _currentContent = content;
    _lastSavedContent = content;
    _quillKey.currentState?.updateContent(content);
    if (mounted) setState(() {});
  }

  void _detachSubscriptions() {
    _contentInsertSubscription?.cancel();
    _contentInsertSubscription = null;
    _contentUpdateSubscription?.cancel();
    _contentUpdateSubscription = null;
    _pathSubscription?.cancel();
    _pathSubscription = null;
    _listenedClient = null;
  }

  Future<void> _saveAndExit() async {
    debugLogger.info('NOTE', 'Exit: $_noteName');
    _debounceTimer?.cancel();
    await _saveContent();
    if (mounted) Navigator.of(context).pop();
  }

  /// Flushes pending edits, optionally against a note other than the one now
  /// on screen.
  ///
  /// Both hosts key this screen by note id, so switching notes normally
  /// remounts it and `dispose` flushes under the old id. `didUpdateWidget`
  /// remains for any unkeyed host: it runs after `widget.noteId` has already
  /// become the new note, so a flush that read the id off the widget would
  /// write the previous note's text over a different file.
  Future<void> _saveContent({String? noteId}) async {
    if (_currentContent == _lastSavedContent) return;

    try {
      debugLogger.save('$_noteName: ${_currentContent.length} chars');
      await _repo.updateNote(noteId ?? widget.noteId, _currentContent);
      _lastSavedContent = _currentContent;
    } catch (e) {
      debugLogger.error('SAVE', '$_noteName failed: $e');
    }
  }
}
