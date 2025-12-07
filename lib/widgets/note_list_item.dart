import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/note.dart';

/// List item component for displaying note preview information
/// Optimized for performance and accessibility
class NoteListItem extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> {
  bool _isHovered = false;

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleLongPress() {
    if (widget.onLongPress != null) {
      HapticFeedback.heavyImpact();
      widget.onLongPress!();
    }
  }

  Color get _borderColor {
    if (widget.isSelected) return SpaceNotesTheme.primary;
    if (_isHovered) return SpaceNotesTheme.textSecondary.withValues(alpha: 0.4);
    return SpaceNotesTheme.textSecondary.withValues(alpha: 0.2);
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
                  // File icon
                  Icon(
                    Icons.description_outlined,
                    color: widget.isSelected
                        ? SpaceNotesTheme.primary
                        : SpaceNotesTheme.textSecondary.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  // File name
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
    );
  }
}

