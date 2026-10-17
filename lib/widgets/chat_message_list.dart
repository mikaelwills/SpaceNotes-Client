import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';
import 'keyboard_dismiss_on_scroll.dart';

const double _followBottomWithin = 24;
const double _scrollButtonAfter = 100;

class ChatScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ChatScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }

  bool get isFollowing =>
      !hasClients || (position as ChatScrollPosition).isFollowing;
}

class ChatScrollPosition extends ScrollPositionWithSingleContext {
  ChatScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  bool get isFollowing =>
      !hasContentDimensions || pixels <= minScrollExtent + _followBottomWithin;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final isFirstLayout = !haveDimensions;
    final applied = super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    if (isFirstLayout && pixels != minScrollExtent) {
      correctPixels(minScrollExtent);
      return false;
    }
    return applied;
  }

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final wasFollowing =
        newPosition.pixels <= oldPosition.minScrollExtent + _followBottomWithin;
    if (wasFollowing &&
        activity is! DragScrollActivity &&
        newPosition.pixels != newPosition.minScrollExtent) {
      correctPixels(newPosition.minScrollExtent);
      return false;
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}

class ChatMessageList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final Key Function(T)? keyBuilder;
  final EdgeInsets padding;
  final String emptyText;
  final bool hydrating;
  final bool showScrollToBottom;
  final double maxWidth;

  const ChatMessageList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.keyBuilder,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 140),
    this.emptyText = 'No messages yet',
    this.hydrating = false,
    this.showScrollToBottom = true,
    this.maxWidth = 800,
  });

  @override
  State<ChatMessageList<T>> createState() => ChatMessageListState<T>();
}

class ChatMessageListState<T> extends State<ChatMessageList<T>> {
  final ChatScrollController _scrollController = ChatScrollController();
  final Key _anchorKey = UniqueKey();
  bool _showScrollButton = false;
  bool _hasShownItems = false;
  bool _following = true;
  int _anchored = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isNotEmpty) _hasShownItems = true;

    if (widget.items.isEmpty) {
      if (_hasShownItems) return const SizedBox.shrink();
      if (widget.hydrating) {
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SpaceNotesTheme.accent,
            ),
          ),
        );
      }
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

    final items = widget.items;
    _anchored = _following
        ? items.length - 1
        : _anchored.clamp(0, items.length - 1);
    final anchored = _anchored;
    final arrived = items.length - anchored;

    return Stack(
      children: [
        KeyboardDismissOnScroll(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: CustomScrollView(
                    controller: _scrollController,
                    reverse: true,
                    center: _anchorKey,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverList(
                        delegate: _delegate(
                          count: arrived,
                          itemAt: (i) => items[anchored + i],
                          spacer: widget.padding.bottom,
                        ),
                      ),
                      SliverList(
                        key: _anchorKey,
                        delegate: _delegate(
                          count: anchored,
                          itemAt: (i) => items[anchored - 1 - i],
                          spacer: widget.padding.top,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showScrollToBottom && _showScrollButton)
          Positioned(
            bottom: 100,
            right: 16,
            child: GestureDetector(
              onTap: scrollToBottom,
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
                    borderRadius:
                        BorderRadius.circular(SpaceNotesTheme.radiusDock),
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: SpaceNotesTheme.accent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  SliverChildBuilderDelegate _delegate({
    required int count,
    required T Function(int index) itemAt,
    required double spacer,
  }) {
    final keyBuilder = widget.keyBuilder;
    final horizontal = EdgeInsets.only(
      left: widget.padding.left,
      right: widget.padding.right,
    );
    return SliverChildBuilderDelegate(
      (context, index) {
        if (index == count) return SizedBox(height: spacer);
        final item = itemAt(index);
        final child = Padding(
          padding: horizontal,
          child: widget.itemBuilder(context, item),
        );
        final key = keyBuilder?.call(item);
        return key == null ? child : KeyedSubtree(key: key, child: child);
      },
      childCount: count + 1,
      findChildIndexCallback: keyBuilder == null
          ? null
          : (key) {
              for (var i = 0; i < count; i++) {
                if (keyBuilder(itemAt(i)) == key) return i;
              }
              return null;
            },
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    final following =
        metrics.pixels <= metrics.minScrollExtent + _followBottomWithin;
    final showButton =
        metrics.pixels > metrics.minScrollExtent + _scrollButtonAfter;
    if (following != _following || showButton != _showScrollButton) {
      setState(() {
        _following = following;
        _showScrollButton = showButton;
      });
    }
    return false;
  }

  Future<void> scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    for (var i = 0; i < 5; i++) {
      if (!mounted || !_scrollController.hasClients) return;
      if (position.pixels == position.minScrollExtent) return;
      position.jumpTo(position.minScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
