import 'dart:convert';
import 'package:flutter/material.dart';
import '../generated/agent_activity.dart';
import '../theme/spacenotes_theme.dart';

class ToolStatusRow extends StatelessWidget {
  final AgentActivity? activity;
  final EdgeInsets padding;

  const ToolStatusRow({
    super.key,
    required this.activity,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final a = activity;
    if (a == null || a.state == 'idle') {
      return const SizedBox.shrink();
    }

    final isToolUse = a.state == 'tool_use';
    final label = isToolUse ? _toolLabel(a.lastToolEvent) : 'thinking...';

    return Padding(
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
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: isToolUse
                    ? SpaceNotesTheme.primary.withValues(alpha: 0.8)
                    : SpaceNotesTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _toolLabel(String? detailJson) {
    if (detailJson == null || detailJson.isEmpty) return 'tool…';
    try {
      final decoded = jsonDecode(detailJson);
      if (decoded is Map<String, dynamic>) {
        final tool = switch (decoded['tool']) {
          final String s when s.isNotEmpty => s,
          _ => 'tool',
        };
        final input = decoded['input'];
        if (input is Map<String, dynamic>) {
          final cmd = input['command'];
          if (cmd is String && cmd.isNotEmpty) {
            final first =
                cmd.contains(' ') ? cmd.substring(0, cmd.indexOf(' ')) : cmd;
            return '$tool $first';
          }
          final path = input['file_path'] ?? input['path'] ?? input['filePath'];
          if (path is String && path.isNotEmpty) {
            final name = path.contains('/')
                ? path.substring(path.lastIndexOf('/') + 1)
                : path;
            return '$tool $name';
          }
        }
        return tool;
      }
    } catch (_) {}
    return 'tool…';
  }
}
