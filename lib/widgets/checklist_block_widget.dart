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
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  State<ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<ChecklistBlockWidget> {
  bool _completedExpanded = false;
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode());

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
                  focusNode: _focusNodeFor(i),
                  onToggle: () => _toggle(i),
                  onTextChanged: (text) => _setText(i, text),
                  onSubmitted: () => _insertAfter(i),
                  onDelete: () => _delete(i),
                ),
            ],
          ),
        _AddItemRow(onTap: _addItem),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 4),
          _CompletedToggle(
            expanded: _completedExpanded,
            onTap: () => setState(() => _completedExpanded = !_completedExpanded),
          ),
          if (_completedExpanded)
            for (final i in completed)
              _ChecklistRow(
                key: ValueKey('item-$i'),
                index: i,
                item: widget.items[i],
                focusNode: _focusNodeFor(i),
                onToggle: () => _toggle(i),
                onTextChanged: (text) => _setText(i, text),
                onSubmitted: () => _insertAfter(i),
                onDelete: () => _delete(i),
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

  void _insertAfter(int index) {
    final next = List<ChecklistItem>.from(widget.items);
    next.insert(index + 1, const ChecklistItem(text: '', checked: false));
    _focusNodeFor(index + 1).requestFocus();
    widget.onChanged(next);
  }

  void _delete(int index) {
    final next = List<ChecklistItem>.from(widget.items);
    next.removeAt(index);
    _focusNodes.remove(index)?.dispose();
    widget.onChanged(next);
  }

  void _addItem() {
    final next = List<ChecklistItem>.from(widget.items);
    next.add(const ChecklistItem(text: '', checked: false));
    _focusNodeFor(next.length - 1).requestFocus();
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

class _AddItemRow extends StatelessWidget {
  const _AddItemRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: SpaceNotesTheme.textSecondary),
              SizedBox(width: 8),
              Text(
                'List Item',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: SpaceNotesTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedToggle extends StatelessWidget {
  const _CompletedToggle({
    required this.expanded,
    required this.onTap,
  });

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
              expanded ? 'Hide checked items' : 'Show checked items',
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
    required this.focusNode,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmitted,
    required this.onDelete,
  });

  final int index;
  final ChecklistItem item;
  final FocusNode focusNode;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onDelete;

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_ChecklistRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.text != widget.item.text && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.item.checked;
    return Padding(
      padding: EdgeInsets.only(left: widget.item.depth * 24.0),
      child: Row(
        key: ValueKey('row-${widget.index}'),
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              onChanged: widget.onTextChanged,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => widget.onSubmitted(),
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: checked ? SpaceNotesTheme.textSecondary : SpaceNotesTheme.text,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                hintText: widget.index == 0 ? 'Item One..' : null,
                hintStyle: const TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: SpaceNotesTheme.textSecondary,
                ),
              ),
            ),
          ),
          if (widget.focusNode.hasFocus)
            GestureDetector(
              onTap: widget.onDelete,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.close,
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
