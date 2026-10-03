import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';

enum DiffLineKind { context, removed, added }

class DiffLine {
  final DiffLineKind kind;
  final String text;

  const DiffLine(this.kind, this.text);
}

List<List<DiffLine>> toolDiffHunks(Map<String, dynamic> input) {
  final edits = input['edits'];
  if (edits is List) {
    return [
      for (final edit in edits)
        if (edit is Map) ..._editHunk(edit['old_string'], edit['new_string']),
    ];
  }
  final single = _editHunk(input['old_string'], input['new_string']);
  if (single.isNotEmpty) return single;
  final content = input['content'];
  if (content is String && content.isNotEmpty) {
    return [
      [for (final line in content.split('\n')) DiffLine(DiffLineKind.added, line)],
    ];
  }
  return const [];
}

List<List<DiffLine>> _editHunk(Object? oldText, Object? newText) {
  if (oldText is! String || newText is! String) return const [];
  final before = oldText.isEmpty ? <String>[] : oldText.split('\n');
  final after = newText.isEmpty ? <String>[] : newText.split('\n');
  var head = 0;
  while (head < before.length &&
      head < after.length &&
      before[head] == after[head]) {
    head++;
  }
  var tail = 0;
  while (tail < before.length - head &&
      tail < after.length - head &&
      before[before.length - 1 - tail] == after[after.length - 1 - tail]) {
    tail++;
  }
  return [
    [
      for (final line in before.sublist(0, head))
        DiffLine(DiffLineKind.context, line),
      for (final line in before.sublist(head, before.length - tail))
        DiffLine(DiffLineKind.removed, line),
      for (final line in after.sublist(head, after.length - tail))
        DiffLine(DiffLineKind.added, line),
      for (final line in before.sublist(before.length - tail))
        DiffLine(DiffLineKind.context, line),
    ],
  ];
}

class ToolDiffView extends StatefulWidget {
  static const collapsedLines = 15;

  final List<List<DiffLine>> hunks;

  const ToolDiffView({super.key, required this.hunks});

  @override
  State<ToolDiffView> createState() => _ToolDiffViewState();
}

class _ToolDiffViewState extends State<ToolDiffView> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final total =
        widget.hunks.fold<int>(0, (sum, hunk) => sum + hunk.length);
    final capped = !_showAll && total > ToolDiffView.collapsedLines;
    final rows = <Widget>[];
    var budget = capped ? ToolDiffView.collapsedLines : total;
    for (var i = 0; i < widget.hunks.length && budget > 0; i++) {
      if (i > 0) rows.add(const _HunkGap());
      for (final line in widget.hunks[i]) {
        if (budget == 0) break;
        rows.add(_DiffLineText(line));
        budget--;
      }
    }

    return Container(
      key: const ValueKey('tool_diff_view'),
      margin: const EdgeInsets.only(top: 6, left: 15),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.bgAlt,
        border: Border.all(color: SpaceNotesTheme.hairline),
        borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  ),
                ),
              ),
            ),
          ),
          if (total > ToolDiffView.collapsedLines)
            GestureDetector(
              key: const ValueKey('tool_diff_show_all'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showAll = !_showAll),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Text(
                  _showAll ? 'show less' : 'show all $total lines',
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    color: SpaceNotesTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HunkGap extends StatelessWidget {
  const _HunkGap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        '⋯',
        style: TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 11,
          color: SpaceNotesTheme.dim,
        ),
      ),
    );
  }
}

class _DiffLineText extends StatelessWidget {
  final DiffLine line;

  const _DiffLineText(this.line);

  @override
  Widget build(BuildContext context) {
    final (prefix, color, background) = switch (line.kind) {
      DiffLineKind.removed => (
          '-',
          SpaceNotesTheme.offline,
          SpaceNotesTheme.offline.withValues(alpha: 0.08),
        ),
      DiffLineKind.added => (
          '+',
          SpaceNotesTheme.online,
          SpaceNotesTheme.online.withValues(alpha: 0.08),
        ),
      DiffLineKind.context => (' ', SpaceNotesTheme.muted, null),
    };
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '$prefix ${line.text}',
        softWrap: false,
        style: TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 11,
          height: 1.45,
          color: color,
        ),
      ),
    );
  }
}
