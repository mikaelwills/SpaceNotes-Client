import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import '../theme/spacenotes_theme.dart';

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
  final _mdDocument = md.Document(encodeHtml: false);
  late final MarkdownToDelta _mdToDelta;
  late final DeltaToMarkdown _deltaToMd;
  bool _isUpdatingFromParent = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _mdToDelta = MarkdownToDelta(markdownDocument: _mdDocument);
    _deltaToMd = DeltaToMarkdown();
    _controller = _createController(widget.initialContent);
    _controller.document.changes.listen((_) {
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
      debugPrint('Error converting markdown to delta: $e');
      return QuillController.basic();
    }
  }

  void _notifyContentChanged() {
    try {
      final markdown = _deltaToMd.convert(_controller.document.toDelta());
      widget.onContentChanged(markdown);
    } catch (e) {
      debugPrint('Error converting delta to markdown: $e');
    }
  }

  void updateContent(String markdown) {
    if (_isUpdatingFromParent) return;
    _isUpdatingFromParent = true;
    try {
      final delta = _mdToDelta.convert(markdown);
      final currentSelection = _controller.selection;
      _controller.document = Document.fromDelta(delta);
      try {
        _controller.updateSelection(currentSelection, ChangeSource.local);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error updating content: $e');
    } finally {
      _isUpdatingFromParent = false;
    }
  }

  String getMarkdown() {
    try {
      return _deltaToMd.convert(_controller.document.toDelta());
    } catch (e) {
      debugPrint('Error getting markdown: $e');
      return '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showToolbar) ...[
          QuillSimpleToolbar(
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
              color: SpaceNotesTheme.surface,
              sectionDividerColor: SpaceNotesTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          Container(
            height: 1,
            color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.2),
          ),
        ],
        Expanded(
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
                paragraph: DefaultTextBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.text,
                    height: 1.6,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(0, 8),
                  const VerticalSpacing(0, 0),
                  null,
                ),
                h1: DefaultTextBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: SpaceNotesTheme.text,
                    height: 1.4,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(16, 8),
                  const VerticalSpacing(0, 0),
                  null,
                ),
                h2: DefaultTextBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SpaceNotesTheme.text,
                    height: 1.4,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(12, 6),
                  const VerticalSpacing(0, 0),
                  null,
                ),
                h3: DefaultTextBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SpaceNotesTheme.text,
                    height: 1.4,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(8, 4),
                  const VerticalSpacing(0, 0),
                  null,
                ),
                code: DefaultTextBlockStyle(
                  TextStyle(
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
                lists: DefaultListBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.text,
                    height: 1.6,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(0, 4),
                  const VerticalSpacing(0, 0),
                  null,
                  null,
                ),
                inlineCode: InlineCodeStyle(
                  style: TextStyle(
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
                placeHolder: DefaultTextBlockStyle(
                  const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    color: SpaceNotesTheme.textSecondary,
                  ),
                  const HorizontalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  const VerticalSpacing(0, 0),
                  null,
                ),
              ),
            ),
          ),
        ),
      ],
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
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 12,
          color: SpaceNotesTheme.textSecondary,
        ),
      ),
    );
  }
}
