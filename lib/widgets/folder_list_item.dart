import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';
import '../generated/folder.dart';

class FolderListItem extends StatefulWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const FolderListItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  State<FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<FolderListItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                    : SpaceNotesTheme.textSecondary.withValues(alpha: 0.2),
                width: widget.isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Folder icon
                Icon(
                  Icons.folder_outlined,
                  color: widget.isSelected
                      ? SpaceNotesTheme.primary
                      : SpaceNotesTheme.primary.withValues(alpha: 0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                // Folder name
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
                // Navigation chevron
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
    );
  }

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
}