import 'package:flutter/material.dart';
import '../models/tool_event.dart';
import '../theme/spacenotes_theme.dart';

class ToolStatusRow extends StatelessWidget {
  final ToolEvent? toolEvent;
  final bool isThinking;
  final EdgeInsets padding;

  const ToolStatusRow({
    super.key,
    this.toolEvent,
    this.isThinking = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final showRow = toolEvent != null || isThinking;
    final showThinking = isThinking && toolEvent == null;

    return AnimatedOpacity(
      opacity: showRow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: SpaceNotesTheme.secondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 6),
            if (showThinking)
              Text(
                'thinking...',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 11,
                  color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            if (toolEvent != null) ...[
              Text(
                toolLabel(toolEvent!.tool.toLowerCase()),
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 11,
                  color: SpaceNotesTheme.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  formatToolDetail(toolEvent!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 11,
                    color: SpaceNotesTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String formatToolDetail(ToolEvent event) {
    final input = event.input;

    final command = input['command'];
    if (command != null && command is String && command.isNotEmpty) {
      final firstWord = command.contains(' ')
          ? command.substring(0, command.indexOf(' '))
          : command;
      return firstWord;
    }

    final filePath = input['file_path'] ?? input['path'] ?? input['filePath'];
    if (filePath != null && filePath is String && filePath.isNotEmpty) {
      return filePath.contains('/')
          ? filePath.substring(filePath.lastIndexOf('/') + 1)
          : filePath;
    }

    final pattern = input['pattern'];
    if (pattern != null && pattern is String && pattern.isNotEmpty) {
      return pattern.length > 30
          ? '${pattern.substring(0, 30)}...'
          : pattern;
    }

    final query = input['query'];
    if (query != null && query is String && query.isNotEmpty) {
      return query.length > 30 ? '${query.substring(0, 30)}...' : query;
    }

    return '';
  }

  static String toolLabel(String tool) {
    const labels = {
      'read': 'read',
      'write': 'write',
      'bash': 'bash',
      'grep': 'search',
      'glob': 'find',
      'edit': 'edit',
      'agent': 'agent',
    };
    if (labels.containsKey(tool)) return labels[tool]!;
    if (tool.contains('spacenotes')) return 'spacenotes';
    if (tool.contains('__')) {
      final parts = tool.split('__');
      return parts.last;
    }
    return tool;
  }
}
