import 'package:flutter/material.dart';
import '../services/checklist_note_parser.dart';
import '../theme/spacenotes_theme.dart';

/// Interactive checklist for a note's task-list block: drag to reorder,
/// tap to check/uncheck, checked items fold under a "N Completed items"
/// toggle. Owns the item list; reports the full new list on any change so
/// the caller can re-serialize it back into the note's markdown.
class ChecklistBlockWidget extends StatefulWidget {
  const ChecklistBlockWidget({
    super.key,
    required this.items,
    required this.onChanged,
    required this.onConvertToText,
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;
  final VoidCallback onConvertToText;

  @override
  State<ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<ChecklistBlockWidget> {
  bool _completedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final active = <int>[];
    final completed = <int>[];
    for (var i = 0; i < widget.items.length; i++) {
      (widget.items[i].checked ? completed : active).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onConvertToText,
            icon: const Icon(Icons.text_fields, size: 16, color: SpaceNotesTheme.textSecondary),
            label: const Text(
              'Convert to text',
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 12,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
          ),
        ),
        if (active.isEmpty && completed.isEmpty)
          const SizedBox.shrink()
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) => _reorderActive(active, oldIndex, newIndex),
            children: [
              for (final i in active)
                _ChecklistRow(
                  key: ValueKey('item-$i'),
                  index: i,
                  item: widget.items[i],
                  onToggle: () => _toggle(i),
                  onTextChanged: (text) => _setText(i, text),
                ),
            ],
          ),
        if (completed.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: 4),
          _CompletedToggle(
            count: completed.length,
            expanded: _completedExpanded,
            onTap: () => setState(() => _completedExpanded = !_completedExpanded),
          ),
          if (_completedExpanded)
            for (final i in completed)
              _ChecklistRow(
                key: ValueKey('item-$i'),
                index: i,
                item: widget.items[i],
                onToggle: () => _toggle(i),
                onTextChanged: (text) => _setText(i, text),
              ),
        ],
      ],
    );
  }

  void _toggle(int index) {
    final next = List<ChecklistItem>.from(widget.items);
    next[index] = next[index].copyWith(checked: !next[index].checked);
    widget.onChanged(next);
  }

  void _setText(int index, String text) {
    final next = List<ChecklistItem>.from(widget.items);
    next[index] = next[index].copyWith(text: text);
    widget.onChanged(next);
  }

  /// [oldIndex]/[newIndex] are positions within the active-only sublist.
  /// `onReorderItem` already adjusts [newIndex] for the removed item at
  /// [oldIndex], so no manual off-by-one shift is needed here. Reorder just
  /// the active items, then walk the full original list emitting each
  /// completed item in place and each active slot from the reordered queue
  /// — this preserves completed items' relative order without ever needing
  /// to compare items by value.
  void _reorderActive(List<int> active, int oldIndex, int newIndex) {
    final activeItems = [for (final i in active) widget.items[i]];
    final moved = activeItems.removeAt(oldIndex);
    activeItems.insert(newIndex, moved);

    final next = <ChecklistItem>[];
    var activeCursor = 0;
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.items[i].checked) {
        next.add(widget.items[i]);
      } else {
        next.add(activeItems[activeCursor]);
        activeCursor++;
      }
    }
    widget.onChanged(next);
  }
}

class _CompletedToggle extends StatelessWidget {
  const _CompletedToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.chevron_right,
                size: 18,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count Completed ${count == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 13,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatefulWidget {
  const _ChecklistRow({
    super.key,
    required this.index,
    required this.item,
    required this.onToggle,
    required this.onTextChanged,
  });

  final int index;
  final ChecklistItem item;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(_ChecklistRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.text != widget.item.text && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.item.checked;
    return Padding(
      padding: EdgeInsets.only(left: widget.item.depth * 24.0),
      child: Row(
        key: ValueKey('row-${widget.index}'),
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: checked ? SpaceNotesTheme.primary : SpaceNotesTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onTextChanged,
              maxLines: null,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: checked ? SpaceNotesTheme.textSecondary : SpaceNotesTheme.text,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.drag_handle,
                size: 18,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
