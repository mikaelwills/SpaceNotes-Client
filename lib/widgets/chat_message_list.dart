import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import 'keyboard_dismiss_on_scroll.dart';

class ChatMessageList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final Key Function(T)? keyBuilder;
  final EdgeInsets padding;
  final String emptyText;
  final bool showScrollToBottom;
  final double maxWidth;
  final ScrollController? scrollController;

  const ChatMessageList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.keyBuilder,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 140),
    this.emptyText = 'No messages yet',
    this.showScrollToBottom = true,
    this.maxWidth = 800,
    this.scrollController,
  });

  @override
  State<ChatMessageList<T>> createState() => ChatMessageListState<T>();
}

class ChatMessageListState<T> extends State<ChatMessageList<T>> {
  ScrollController? _ownScrollController;
  bool _showScrollButton = false;
  bool _autoScrollEnabled = true;

  @override
  void didUpdateWidget(ChatMessageList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScrollButtonVisibility();
    });
  }

  @override
  void dispose() {
    _ownScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: TextStyle(
            color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      );
    }

    return Stack(
      children: [
        KeyboardDismissOnScroll(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final isNearBottom = _scrollController.position.pixels < 100;
                if (_showScrollButton == isNearBottom) {
                  setState(() => _showScrollButton = !isNearBottom);
                }
                if (notification.dragDetails != null) {
                  _autoScrollEnabled = isNearBottom;
                }
              }
              return false;
            },
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      widget.padding.left,
                      widget.padding.bottom,
                      widget.padding.right,
                      widget.padding.top,
                    ),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item =
                          widget.items[widget.items.length - 1 - index];
                      final child = widget.itemBuilder(context, item);
                      final k = widget.keyBuilder?.call(item);
                      return k == null
                          ? child
                          : KeyedSubtree(key: k, child: child);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showScrollToBottom && _showScrollButton)
          _buildScrollToBottomButton(),
      ],
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: forceScrollToBottom,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'scroll to bottom',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SpaceNotesTheme.bgAlt,
              border: Border.all(
                color: SpaceNotesTheme.hairlineStrong,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusDock),
            ),
            child: const Icon(
              Icons.arrow_downward,
              size: 16,
              color: SpaceNotesTheme.accent,
            ),
          ),
        ),
      ),
    );
  }

  ScrollController get _scrollController =>
      widget.scrollController ?? (_ownScrollController ??= ScrollController());

  void _syncScrollButtonVisibility() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return;
    final isNearBottom = pos.pixels < 100;
    if (_showScrollButton == isNearBottom) {
      setState(() => _showScrollButton = !isNearBottom);
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void forceScrollToBottom() {
    _autoScrollEnabled = true;
    scrollToBottom();
  }
}
