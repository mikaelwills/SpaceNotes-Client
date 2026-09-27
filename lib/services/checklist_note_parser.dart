/// One checklist item: its text, checked state, and nesting depth (0 = top
/// level, 1 = one indent). Order in the list IS the display/drag order.
class ChecklistItem {
  const ChecklistItem({
    required this.text,
    required this.checked,
    this.depth = 0,
  });

  final String text;
  final bool checked;
  final int depth;

  ChecklistItem copyWith({String? text, bool? checked, int? depth}) {
    return ChecklistItem(
      text: text ?? this.text,
      checked: checked ?? this.checked,
      depth: depth ?? this.depth,
    );
  }
}

/// A checklist block found inside a note body: the parsed items plus the
/// exact character range it occupied in the original body, so the rest of
/// the note (prose above/below) can be preserved untouched on save.
class ChecklistBlock {
  const ChecklistBlock({
    required this.items,
    required this.start,
    required this.end,
  });

  final List<ChecklistItem> items;

  /// Index into the original body where the block starts (inclusive).
  final int start;

  /// Index into the original body where the block ends (exclusive).
  final int end;
}

final _checklistLine = RegExp(r'^( *)- \[( |x|X)\] (.*)$');

/// Finds and parses the first contiguous run of markdown task-list lines
/// (`- [ ] text` / `- [x] text`, optionally indented in 4-space steps for one
/// level of nesting) in [body]. Returns null if none exists.
///
/// Only one checklist block is supported per note in v1 — the first
/// contiguous run found, scanning top to bottom.
class ChecklistNoteParser {
  static ChecklistBlock? findBlock(String body) {
    final lines = body.split('\n');
    var lineStart = 0;
    final lineOffsets = <int>[];
    for (final line in lines) {
      lineOffsets.add(lineStart);
      lineStart += line.length + 1;
    }

    int? blockStartLine;
    int? blockEndLine;
    for (var i = 0; i < lines.length; i++) {
      final isChecklistLine = _checklistLine.hasMatch(lines[i]);
      if (isChecklistLine && blockStartLine == null) {
        blockStartLine = i;
      }
      if (!isChecklistLine && blockStartLine != null) {
        blockEndLine = i;
        break;
      }
    }
    if (blockStartLine == null) return null;
    blockEndLine ??= lines.length;

    final items = <ChecklistItem>[];
    for (var i = blockStartLine; i < blockEndLine; i++) {
      final match = _checklistLine.firstMatch(lines[i]);
      if (match == null) continue;
      final indent = match.group(1)!.length;
      items.add(
        ChecklistItem(
          text: match.group(3)!,
          checked: match.group(2)!.toLowerCase() == 'x',
          depth: (indent / 4).round().clamp(0, 1),
        ),
      );
    }
    if (items.isEmpty) return null;

    final start = lineOffsets[blockStartLine];
    final end = blockEndLine < lineOffsets.length
        ? lineOffsets[blockEndLine]
        : body.length;

    return ChecklistBlock(items: items, start: start, end: end);
  }

  /// Renders [items] back to markdown task-list lines, one per line,
  /// terminated with a single trailing newline (matches how the block was
  /// found — every line including the last had a `\n` after it, since a
  /// non-checklist line or EOF ended the run).
  static String serialize(List<ChecklistItem> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      final indent = '    ' * item.depth;
      final box = item.checked ? '[x]' : '[ ]';
      buffer.writeln('$indent- $box ${item.text}');
    }
    return buffer.toString();
  }

  /// Replaces the checklist block in [body] with [items] serialized back to
  /// markdown, leaving everything before/after the block untouched.
  static String replaceBlock(String body, ChecklistBlock block, List<ChecklistItem> items) {
    final before = body.substring(0, block.start);
    final after = body.substring(block.end);
    return '$before${serialize(items)}$after';
  }

  /// Converts a checklist back to plain text lines, dropping the `- [ ]`/
  /// `- [x]` markers (the reverse of the "Convert to Checklist" toolbar
  /// action). Checked state is discarded — there's no plain-text equivalent.
  static String toPlainText(List<ChecklistItem> items) {
    return items.map((item) => item.text).join('\n');
  }
}
