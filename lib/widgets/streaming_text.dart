import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import '../theme/spacenotes_theme.dart';
import '../utils/text_sanitizer.dart';

class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delay;
  final bool isStreaming;
  final bool useMarkdown;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.delay = const Duration(milliseconds: 20),
    this.isStreaming = true,
    this.useMarkdown = false,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> with SingleTickerProviderStateMixin {
  String _displayedText = '';
  String _sanitizedFullText = '';
  Timer? _timer;
  int _currentIndex = 0;
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    )..repeat(reverse: true);
    _cursorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_cursorController);

    _sanitizedFullText = _safeTextSanitize(widget.text, preserveMarkdown: widget.useMarkdown);

    if (widget.isStreaming) {
      _startStreaming();
    } else {
      _displayedText = _sanitizedFullText;
    }
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text) {
      final newSanitizedText = _safeTextSanitize(widget.text, preserveMarkdown: widget.useMarkdown);

      _timer?.cancel();
      if (widget.isStreaming) {
        setState(() {
          _sanitizedFullText = newSanitizedText;
          _displayedText = newSanitizedText;
          _currentIndex = newSanitizedText.length;
        });
      } else {
        _sanitizedFullText = newSanitizedText;
        _displayedText = newSanitizedText;
      }
    } else if (widget.isStreaming != oldWidget.isStreaming) {
      if (widget.isStreaming) {
        setState(() {
          _displayedText = _sanitizedFullText;
          _currentIndex = _sanitizedFullText.length;
        });
      } else {
        _timer?.cancel();
        _displayedText = _sanitizedFullText;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  void _startStreaming() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.delay, (timer) {
      if (_currentIndex < _sanitizedFullText.length) {
        setState(() {
          _currentIndex++;
          while (_currentIndex < _sanitizedFullText.length &&
                 _isLowSurrogate(_sanitizedFullText.codeUnitAt(_currentIndex))) {
            _currentIndex++;
          }
          _displayedText = _sanitizedFullText.substring(0, _currentIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  bool _isLowSurrogate(int codeUnit) {
    return codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
  }

  Widget _buildBlinkingCursor() {
    return AnimatedBuilder(
      animation: _cursorAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _cursorAnimation.value,
          child: Text(
            '▌',
            style: widget.style?.copyWith(
              color: SpaceNotesTheme.primary,
            ) ?? const TextStyle(color: SpaceNotesTheme.primary),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMarkdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: _displayedText,
            styleSheet: MarkdownStyleSheet(
              p: widget.style ?? SpaceNotesTextStyles.terminal,
              code: SpaceNotesTextStyles.code,
              codeblockDecoration: BoxDecoration(
                color: SpaceNotesTheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              codeblockPadding: const EdgeInsets.all(8),
              blockquote: (widget.style ?? SpaceNotesTextStyles.terminal).copyWith(
                color: SpaceNotesTheme.textSecondary,
              ),
              blockquoteDecoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: SpaceNotesTheme.textSecondary,
                    width: 2,
                  ),
                ),
              ),
              h1: (widget.style ?? SpaceNotesTextStyles.terminal).copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              h2: (widget.style ?? SpaceNotesTextStyles.terminal).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              h3: (widget.style ?? SpaceNotesTextStyles.terminal).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              listBullet: widget.style ?? SpaceNotesTextStyles.terminal,
              listIndent: 16,
            ),
            selectable: true,
          ),
          if (widget.isStreaming) _buildBlinkingCursor(),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            _displayedText,
            style: widget.style,
          ),
        ),
        if (widget.isStreaming) _buildBlinkingCursor(),
      ],
    );
  }

  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [StreamingText] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }
}