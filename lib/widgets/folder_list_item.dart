import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/folder.dart';

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

class _FolderListItemState extends State<FolderListItem> with SingleTickerProviderStateMixin {
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
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _swipeOffset = (_swipeOffset + details.delta.dx).clamp(-_maxSwipe, 0);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_swipeOffset < -_maxSwipe / 2) {
                  _animateToOffset(-_maxSwipe);
                } else {
                  _animateToOffset(0);
                }
              },
              child: Material(
                color: widget.isSelected
                    ? SpaceNotesTheme.primary.withValues(alpha: 0.1)
                    : SpaceNotesTheme.surface,
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
                        color: widget.isSelected
                            ? SpaceNotesTheme.primary
                            : SpaceNotesTheme.textSecondary.withValues(alpha: 0.1),
                        width: widget.isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: widget.isSelected
                              ? SpaceNotesTheme.primary
                              : SpaceNotesTheme.primary.withValues(alpha: 0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.folder.name,
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
                        Icon(
                          Icons.chevron_right,
                          color: widget.isSelected
                              ? SpaceNotesTheme.primary
                              : SpaceNotesTheme.textSecondary,
                          size: 20,
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
}