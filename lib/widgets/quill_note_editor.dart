import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import '../theme/spacenotes_theme.dart';
import '../services/debug_logger.dart';

class _KeepEmptyLineBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^(?:[ \t]*)$');

  const _KeepEmptyLineBlockSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    parser.advance();
    return md.Element.text('p', '');
  }
}

class QuillNoteEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onContentChanged;
  final FocusNode? focusNode;
  final bool showToolbar;

  const QuillNoteEditor({
    super.key,
    required this.initialContent,
    required this.onContentChanged,
    this.focusNode,
    this.showToolbar = true,
  });

  @override
  State<QuillNoteEditor> createState() => QuillNoteEditorState();
}

class QuillNoteEditorState extends State<QuillNoteEditor> {
  late QuillController _controller;
  late FocusNode _focusNode;
  late FocusNode _rawFocusNode;
  late TextEditingController _rawController;
  final _mdDocument = md.Document(
    encodeHtml: false,
    blockSyntaxes: [const _KeepEmptyLineBlockSyntax()],
  );
  late final MarkdownToDelta _mdToDelta;
  late final DeltaToMarkdown _deltaToMd;
  bool _isUpdatingFromParent = false;
  bool _isRawMode = false;
  bool _toolbarExpanded = false;
  StreamSubscription? _documentChangesSubscription;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _rawFocusNode = FocusNode();
    _rawController = TextEditingController(text: widget.initialContent);
    _mdToDelta = MarkdownToDelta(
      markdownDocument: _mdDocument,
      softLineBreak: true,
    );
    _deltaToMd = DeltaToMarkdown(
      visitLineHandleNewLine: (style, out) => out.writeln(),
    );
    _controller = _createController(widget.initialContent);
    _attachDocumentListener();
  }

  void _attachDocumentListener() {
    _documentChangesSubscription?.cancel();
    _documentChangesSubscription = _controller.document.changes.listen((_) {
      if (!_isUpdatingFromParent) {
        _notifyContentChanged();
      }
    });
  }

  QuillController _createController(String markdown) {
    if (markdown.isEmpty) {
      return QuillController.basic();
    }
    try {
      final delta = _mdToDelta.convert(markdown);
      return QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      debugLogger.error('EDITOR', 'Error converting markdown to delta: $e');
      return QuillController.basic();
    }
  }

  void _notifyContentChanged() {
    try {
      final markdown = _deltaToMd.convert(_controller.document.toDelta());
      widget.onContentChanged(markdown);
    } catch (e) {
      debugLogger.error('EDITOR', 'Error converting delta to markdown: $e');
    }
  }

  void updateContent(String markdown) {
    if (_isUpdatingFromParent) return;
    _isUpdatingFromParent = true;
    try {
      final delta = _mdToDelta.convert(markdown);
      final currentSelection = _controller.selection;
      _controller.document = Document.fromDelta(delta);
      _attachDocumentListener();
      try {
        _controller.updateSelection(currentSelection, ChangeSource.local);
      } catch (_) {}
    } catch (e) {
      debugLogger.error('EDITOR', 'Error updating content: $e');
    } finally {
      _isUpdatingFromParent = false;
    }
  }

  String getMarkdown() {
    try {
      return _deltaToMd.convert(_controller.document.toDelta());
    } catch (e) {
      debugLogger.error('EDITOR', 'Error getting markdown: $e');
      return '';
    }
  }

  void undo() {
    _controller.undo();
  }

  void redo() {
    _controller.redo();
  }

  bool get canUndo => _controller.hasUndo;
  bool get canRedo => _controller.hasRedo;

  void _toggleRawMode() {
    setState(() {
      if (_isRawMode) {
        final rawText = _rawController.text;
        _isUpdatingFromParent = true;
        try {
          final delta = _mdToDelta.convert(rawText);
          _controller.document = Document.fromDelta(delta);
          _attachDocumentListener();
        } catch (e) {
          debugLogger.error('EDITOR', 'Error converting markdown to delta: $e');
        }
        _isUpdatingFromParent = false;
        widget.onContentChanged(rawText);
      } else {
        _rawController.text = _cleanMarkdown(getMarkdown());
      }
      _isRawMode = !_isRawMode;
    });
  }

  String _cleanMarkdown(String markdown) {
    return markdown
        .replaceAll(r'\-', '-')
        .replaceAll(r'\.', '.')
        .replaceAll(r'\!', '!')
        .replaceAll(r'\#', '#')
        .replaceAll(r'\*', '*')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\[', '[')
        .replaceAll(r'\]', ']')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')');
  }

  Widget _buildRawEditor() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: TextField(
          controller: _rawController,
          focusNode: _rawFocusNode,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: SpaceNotesTheme.text,
            height: 1.6,
          ),
          cursorColor: SpaceNotesTheme.primary,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintText: 'Raw markdown...',
            hintStyle: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.textSecondary,
            ),
          ),
          onChanged: (value) {
            widget.onContentChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildQuillEditor() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: QuillEditor.basic(
        controller: _controller,
        focusNode: _focusNode,
      config: QuillEditorConfig(
        padding: const EdgeInsets.all(16),
        placeholder: 'Start writing...',
        embedBuilders: [
          _DividerEmbedBuilder(),
        ],
        unknownEmbedBuilder: _UnknownEmbedBuilder(),
        customStyles: DefaultStyles(
          paragraph: const DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              height: 1.6,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(0, 8),
            VerticalSpacing(0, 0),
            null,
          ),
          h1: const DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(16, 8),
            VerticalSpacing(0, 0),
            null,
          ),
          h2: const DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(12, 6),
            VerticalSpacing(0, 0),
            null,
          ),
          h3: const DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(8, 4),
            VerticalSpacing(0, 0),
            null,
          ),
          code: DefaultTextBlockStyle(
            const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 13,
              color: SpaceNotesTheme.primary,
              backgroundColor: SpaceNotesTheme.inputSurface,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(8, 8),
            const VerticalSpacing(0, 0),
            BoxDecoration(
              color: SpaceNotesTheme.inputSurface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          quote: DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(8, 8),
            const VerticalSpacing(0, 0),
            BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
          ),
          lists: const DefaultListBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              height: 1.6,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(0, 4),
            VerticalSpacing(0, 0),
            null,
            null,
          ),
          inlineCode: InlineCodeStyle(
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 13,
              color: SpaceNotesTheme.primary,
              backgroundColor: SpaceNotesTheme.inputSurface,
            ),
          ),
          link: const TextStyle(
            color: SpaceNotesTheme.primary,
            decoration: TextDecoration.underline,
          ),
          placeHolder: const DefaultTextBlockStyle(
            TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.textSecondary,
            ),
            HorizontalSpacing(0, 0),
            VerticalSpacing(0, 0),
            VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
      ),
    );
  }

  @override
  void dispose() {
    _documentChangesSubscription?.cancel();
    _controller.dispose();
    _rawController.dispose();
    _rawFocusNode.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showToolbar) _buildCollapsibleToolbar(),
        Expanded(
          child: _isRawMode ? _buildRawEditor() : _buildQuillEditor(),
        ),
      ],
    );
  }

  Widget _buildCollapsibleToolbar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
            icon: AnimatedRotation(
              turns: _toolbarExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.chevron_right,
                color: SpaceNotesTheme.text,
                size: 24,
              ),
            ),
            tooltip: _toolbarExpanded ? 'Hide toolbar' : 'Show toolbar',
          ),
          Expanded(
            child: ClipRect(
              child: AnimatedSlide(
                offset: Offset(_toolbarExpanded ? 0 : -1, 0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _toolbarExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: QuillSimpleToolbar(
                      controller: _controller,
                      config: QuillSimpleToolbarConfig(
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: false,
                        showStrikeThrough: true,
                        showInlineCode: true,
                        showCodeBlock: true,
                        showListNumbers: true,
                        showListBullets: true,
                        showListCheck: true,
                        showQuote: true,
                        showLink: true,
                        showHeaderStyle: true,
                        showDividers: true,
                        showFontFamily: false,
                        showFontSize: false,
                        showBackgroundColorButton: false,
                        showColorButton: false,
                        showClearFormat: false,
                        showAlignmentButtons: false,
                        showLeftAlignment: false,
                        showCenterAlignment: false,
                        showRightAlignment: false,
                        showJustifyAlignment: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showSmallButton: false,
                        showIndent: false,
                        showDirection: false,
                        showUndo: false,
                        showRedo: false,
                        showClipboardCopy: false,
                        showClipboardCut: false,
                        showClipboardPaste: false,
                        color: Colors.transparent,
                        sectionDividerColor: SpaceNotesTheme.textSecondary.withValues(alpha: 0.2),
                        customButtons: [
                          QuillToolbarCustomButtonOptions(
                            icon: Icon(
                              _isRawMode ? Icons.visibility : Icons.code,
                              size: 18,
                              color: SpaceNotesTheme.text,
                            ),
                            tooltip: _isRawMode ? 'Show Preview' : 'Show Raw Markdown',
                            onPressed: _toggleRawMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'divider';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }
}

class _UnknownEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.inputSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '[${embedContext.node.value.type}]',
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 12,
          color: SpaceNotesTheme.textSecondary,
        ),
      ),
    );
  }
}
