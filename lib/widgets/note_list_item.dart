import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/space_file.dart';
import 'swipe_action.dart';

class _LeftOnlyHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    return estimate.pixelsPerSecond.dx.abs() > minVelocity;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
      PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved < -kTouchSlop;
  }
}

class NoteListItem extends StatefulWidget {
  final SpaceFile note;
  final int? index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    this.index,
    this.onLongPress,
    this.onDelete,
    this.onMove,
    this.isSelected = false,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  double _swipeOffset = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const double _actionButtonWidth = 88;
  static const double _maxSwipe = 176;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onMove != null)
                  SwipeAction(
                    icon: Icons.drive_file_move_outline,
                    label: 'move',
                    color: SpaceNotesTheme.accent,
                    width: _actionButtonWidth,
                    onTap: () {
                      _animateToOffset(0);
                      widget.onMove!();
                    },
                  ),
                if (widget.onDelete != null)
                  SwipeAction(
                    icon: Icons.delete_outline,
                    label: 'delete',
                    color: SpaceNotesTheme.offline,
                    width: _actionButtonWidth,
                    onTap: () {
                      _animateToOffset(0);
                      widget.onDelete!();
                    },
                  ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final offset = _animationController.isAnimating
                  ? _animation.value
                  : _swipeOffset;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: RawGestureDetector(
              gestures: {
                _LeftOnlyHorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _LeftOnlyHorizontalDragGestureRecognizer>(
                  () => _LeftOnlyHorizontalDragGestureRecognizer(),
                  (_LeftOnlyHorizontalDragGestureRecognizer instance) {
                    instance
                      ..onUpdate = (details) {
                        setState(() {
                          _swipeOffset = (_swipeOffset + details.delta.dx)
                              .clamp(-_maxSwipe, 0);
                        });
                      }
                      ..onEnd = (details) {
                        if (_swipeOffset < -_maxSwipe / 2) {
                          _animateToOffset(-_maxSwipe);
                        } else {
                          _animateToOffset(0);
                        }
                      };
                  },
                ),
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: Material(
                  color: _backgroundColor,
                  child: InkWell(
                    onTap: _handleTap,
                    onLongPress: _handleLongPress,
                    splashColor: SpaceNotesTheme.accent.withValues(alpha: 0.1),
                    highlightColor:
                        SpaceNotesTheme.accent.withValues(alpha: 0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _borderColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.index != null) ...[
                            SizedBox(
                              width: 28,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  widget.index!.toString().padLeft(3, '0'),
                                  style: const TextStyle(
                                    fontFamily: SpaceNotesTheme.fontMono,
                                    fontSize: 9,
                                    color: SpaceNotesTheme.dim,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.description_outlined,
                              color: widget.isSelected
                                  ? SpaceNotesTheme.accent
                                  : SpaceNotesTheme.dim,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.note.name,
                                  style: TextStyle(
                                    fontFamily: SpaceNotesTheme.fontSans,
                                    fontSize: 15,
                                    color: widget.isSelected
                                        ? SpaceNotesTheme.accent
                                        : SpaceNotesTheme.fg,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                    height: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (_previewText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _previewText,
                                    style: const TextStyle(
                                      fontFamily: SpaceNotesTheme.fontSans,
                                      fontSize: 12,
                                      color: SpaceNotesTheme.muted,
                                      height: 1.4,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _timeAgo,
                              style: const TextStyle(
                                fontFamily: SpaceNotesTheme.fontMono,
                                fontSize: 10,
                                color: SpaceNotesTheme.dim,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap() {
    if (_swipeOffset != 0) {
      _animateToOffset(0);
      return;
    }
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleLongPress() {
    if (widget.onLongPress != null) {
      HapticFeedback.heavyImpact();
      widget.onLongPress!();
    }
  }

  void _animateToOffset(double target) {
    _animation = Tween<double>(begin: _swipeOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0).then((_) {
      setState(() => _swipeOffset = target);
    });
  }

  Color get _borderColor {
    if (widget.isSelected) return SpaceNotesTheme.accent;
    if (_isHovered) return SpaceNotesTheme.hairlineStrong;
    return SpaceNotesTheme.hairline;
  }

  Color get _backgroundColor {
    if (widget.isSelected) {
      return SpaceNotesTheme.accent.withValues(alpha: 0.06);
    }
    return SpaceNotesTheme.bg;
  }

  String get _previewText {
    final raw = widget.note.content.trim();
    if (raw.isEmpty) return '';
    final firstLine = raw.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return firstLine.trim();
  }

  String get _timeAgo {
    final ms = widget.note.modifiedTime.toInt();
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }
}
