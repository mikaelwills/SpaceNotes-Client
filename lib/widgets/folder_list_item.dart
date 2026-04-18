import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/folder.dart';
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

class FolderListItem extends StatefulWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final bool isSelected;

  const FolderListItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onMove,
    this.isSelected = false,
  });

  @override
  State<FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<FolderListItem>
    with SingleTickerProviderStateMixin {
  double _swipeOffset = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const double _actionButtonWidth = 60;
  static const double _maxSwipe = 120;

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
              child: Material(
                color: widget.isSelected
                    ? SpaceNotesTheme.accent.withValues(alpha: 0.06)
                    : SpaceNotesTheme.bg,
                child: InkWell(
                  onTap: _handleTap,
                  onLongPress: _handleLongPress,
                  splashColor: SpaceNotesTheme.accent.withValues(alpha: 0.1),
                  highlightColor:
                      SpaceNotesTheme.accent.withValues(alpha: 0.05),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: widget.isSelected
                              ? SpaceNotesTheme.accent
                              : SpaceNotesTheme.hairline,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: widget.isSelected
                              ? SpaceNotesTheme.accent
                              : SpaceNotesTheme.accent.withValues(alpha: 0.75),
                          size: 15,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.folder.name.contains('/')
                                ? widget.folder.name.split('/').last
                                : widget.folder.name,
                            style: TextStyle(
                              fontFamily: SpaceNotesTheme.fontSans,
                              fontSize: 15,
                              color: widget.isSelected
                                  ? SpaceNotesTheme.accent
                                  : SpaceNotesTheme.fg,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: widget.isSelected
                              ? SpaceNotesTheme.accent
                              : SpaceNotesTheme.dim,
                          size: 16,
                        ),
                      ],
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
}
