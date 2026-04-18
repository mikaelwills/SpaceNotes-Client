import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import 'keyboard_dismiss_on_scroll.dart';

class ChatMessageList extends StatefulWidget {
  final List<Widget> items;
  final EdgeInsets padding;
  final String emptyText;
  final bool showScrollToBottom;
  final double maxWidth;
  final ScrollController? scrollController;

  const ChatMessageList({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 120),
    this.emptyText = 'No messages yet',
    this.showScrollToBottom = true,
    this.maxWidth = 800,
    this.scrollController,
  });

  @override
  State<ChatMessageList> createState() => ChatMessageListState();
}

class ChatMessageListState extends State<ChatMessageList> {
  ScrollController? _ownScrollController;
  bool _showScrollButton = false;
  bool _autoScrollEnabled = true;
  int _previousItemCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScrollButtonVisibility();
    });
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length > _previousItemCount && _autoScrollEnabled) {
      scrollToBottom();
    }
    _previousItemCount = widget.items.length;
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
                final isNearBottom = _scrollController.position.pixels >=
                    _scrollController.position.maxScrollExtent - 100;
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: widget.padding,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) => widget.items[index],
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
      bottom: 76,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.inputSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: forceScrollToBottom,
                  tooltip: 'Scroll to bottom',
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 24,
                    color: SpaceNotesTheme.primary,
                  ),
                ),
              ),
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
    final isNearBottom = pos.pixels >= pos.maxScrollExtent - 100;
    if (_showScrollButton == isNearBottom) {
      setState(() => _showScrollButton = !isNearBottom);
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
