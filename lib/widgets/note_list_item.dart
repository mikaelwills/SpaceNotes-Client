import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/note.dart';

class _LeftOnlyHorizontalDragGestureRecognizer extends HorizontalDragGestureRecognizer {

  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    return estimate.pixelsPerSecond.dx.abs() > minVelocity;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved < -kTouchSlop;
  }
}

class NoteListItem extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onMove,
    this.isSelected = false,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
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
    if (widget.isSelected) return SpaceNotesTheme.primary;
    if (_isHovered) return SpaceNotesTheme.textSecondary.withValues(alpha: 0.2);
    return SpaceNotesTheme.textSecondary.withValues(alpha: 0.1);
  }

  Color get _backgroundColor {
    if (widget.isSelected) return SpaceNotesTheme.primary.withValues(alpha: 0.1);
    if (_isHovered) return SpaceNotesTheme.surface;
    return SpaceNotesTheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onMove != null)
                  GestureDetector(
                    onTap: () {
                      _animateToOffset(0);
                      widget.onMove!();
                    },
                    child: Container(
                      width: _actionButtonWidth,
                      color: SpaceNotesTheme.primary,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.drive_file_move_outline,
                        color: SpaceNotesTheme.background,
                        size: 20,
                      ),
                    ),
                  ),
                if (widget.onDelete != null)
                  GestureDetector(
                    onTap: () {
                      _animateToOffset(0);
                      widget.onDelete!();
                    },
                    child: Container(
                      width: _actionButtonWidth,
                      color: SpaceNotesTheme.error,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.delete_outline,
                        color: SpaceNotesTheme.background,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final offset = _animationController.isAnimating ? _animation.value : _swipeOffset;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: RawGestureDetector(
              gestures: {
                _LeftOnlyHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<_LeftOnlyHorizontalDragGestureRecognizer>(
                  () => _LeftOnlyHorizontalDragGestureRecognizer(),
                  (_LeftOnlyHorizontalDragGestureRecognizer instance) {
                    instance
                      ..onUpdate = (details) {
                        setState(() {
                          _swipeOffset = (_swipeOffset + details.delta.dx).clamp(-_maxSwipe, 0);
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
                    splashColor: SpaceNotesTheme.primary.withValues(alpha: 0.1),
                    highlightColor: SpaceNotesTheme.primary.withValues(alpha: 0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _borderColor,
                          width: widget.isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: widget.isSelected
                                ? SpaceNotesTheme.primary
                                : SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.note.name,
                              style: TextStyle(
                                fontFamily: 'FiraCode',
                                fontSize: 14,
                                color: widget.isSelected
                                    ? SpaceNotesTheme.primary
                                    : SpaceNotesTheme.text,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
}

