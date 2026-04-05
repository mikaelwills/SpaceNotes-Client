import 'package:flutter/material.dart';
import '../models/space_message.dart';
import '../theme/spacenotes_theme.dart';
import 'keyboard_dismiss_on_scroll.dart';
import 'terminal_message.dart';

typedef MessageItemBuilder = Widget Function(SpaceMessage message, int index);

class ChatMessageList extends StatefulWidget {
  final List<SpaceMessage> messages;
  final MessageItemBuilder? itemBuilder;
  final EdgeInsets padding;
  final String emptyText;
  final bool showScrollToBottom;
  final double maxWidth;
  final ScrollController? scrollController;

  const ChatMessageList({
    super.key,
    required this.messages,
    this.itemBuilder,
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
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
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
    if (widget.messages.isEmpty) {
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
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: widget.padding,
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      if (widget.itemBuilder != null) {
                        return widget.itemBuilder!(widget.messages[index], index);
                      }
                      return TerminalMessage(message: widget.messages[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showScrollToBottom && _showScrollButton) _buildScrollToBottomButton(),
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
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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

  void onMessagesChanged(int newCount) {
    if (newCount > _previousMessageCount && _autoScrollEnabled) {
      scrollToBottom();
    }
    _previousMessageCount = newCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScrollButtonVisibility();
    });
  }

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
