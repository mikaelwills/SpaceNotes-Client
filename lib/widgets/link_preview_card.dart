import 'package:flutter/material.dart';

import '../generated/space_file.dart';
import '../theme/spacenotes_theme.dart';

class LinkPreviewIconCard extends StatelessWidget {
  const LinkPreviewIconCard({
    super.key,
    required this.file,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final SpaceFile file;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: SpaceNotesTheme.card,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(child: Icon(icon, size: 40, color: color)),
              ),
              Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontSans,
                  fontSize: 13,
                  color: SpaceNotesTheme.fg,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
