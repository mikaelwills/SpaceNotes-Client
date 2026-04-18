import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/message.dart';
import '../generated/permission_request.dart';
import '../generated/tool_event.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';

class TerminalMessage extends StatelessWidget {
  final Message message;

  const TerminalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') return _buildUserMessage(context);
    return _buildAssistantMessage(context);
  }

  Widget _buildUserMessage(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _copy(context, message.text),
      child: Row(
        children: [
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1214),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    message.text,
                    style: SpaceNotesTextStyles.terminal.copyWith(
                      color: SpaceNotesTheme.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _time,
                    style: SpaceNotesTextStyles.terminal.copyWith(
                      color: const Color(0xFF555555),
                      fontFamily: 'FiraCode',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    final sourceColor = _sourceColor;
    return GestureDetector(
      onLongPress: () => _copy(context, message.text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1214),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _time,
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    color: const Color(0xFF555555),
                    fontFamily: 'FiraCode',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message.source.toUpperCase(),
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    color: sourceColor,
                    fontFamily: 'FiraCode',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.text,
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _time {
    final dt = timestampToDateTime(message.createdAt);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color get _sourceColor {
    switch (message.source) {
      case 'mcp':
        return SpaceNotesTheme.primary;
      case 'hook':
        return const Color(0xFFF5E27A);
      default:
        return SpaceNotesTheme.textSecondary;
    }
  }

  void _copy(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
  }
}

class ToolEventRow extends StatelessWidget {
  final ToolEvent event;

  const ToolEventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final detail = _parseDetail(event.detail);
    final summary = _summarize(detail);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.play_arrow_outlined,
              size: 14, color: SpaceNotesTheme.secondary),
          const SizedBox(width: 6),
          Text(
            event.tool,
            style: SpaceNotesTextStyles.terminal.copyWith(
              color: SpaceNotesTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                summary,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.textSecondary,
                  fontFamily: 'FiraCode',
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            _time,
            style: SpaceNotesTextStyles.terminal.copyWith(
              color: const Color(0xFF555555),
              fontFamily: 'FiraCode',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String get _time {
    final dt = timestampToDateTime(event.startedAt);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class PermissionRow extends ConsumerWidget {
  final PermissionRequest request;

  const PermissionRow({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = _parseDetail(request.input);
    final description = switch (detail['description']) {
      final String s => s,
      _ => '',
    };
    final inputPreview = switch (detail['input_preview']) {
      final String s => s,
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1214),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: SpaceNotesTheme.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 14, color: SpaceNotesTheme.warning),
              const SizedBox(width: 6),
              Text(
                request.tool,
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.text,
                fontSize: 12,
              ),
            ),
          ],
          if (inputPreview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              inputPreview.length > 120
                  ? '${inputPreview.substring(0, 120)}...'
                  : inputPreview,
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.textSecondary,
                fontFamily: 'FiraCode',
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _PermissionButton(
                label: 'Allow',
                color: SpaceNotesTheme.success,
                onTap: () => respondToPermission(ref,
                    requestId: request.id, allow: true),
              ),
              const SizedBox(width: 12),
              _PermissionButton(
                label: 'Deny',
                color: SpaceNotesTheme.error,
                onTap: () => respondToPermission(ref,
                    requestId: request.id, allow: false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PermissionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: SpaceNotesTextStyles.terminal.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _parseDetail(String jsonStr) {
  if (jsonStr.isEmpty) return const {};
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  } catch (_) {
    return const {};
  }
}

String _summarize(Map<String, dynamic> detail) {
  final input = detail['input'];
  if (input is! Map<String, dynamic>) return '';
  final command = input['command'];
  if (command is String && command.isNotEmpty) {
    return command.length > 60 ? '${command.substring(0, 60)}...' : command;
  }
  final path = input['file_path'] ?? input['path'] ?? input['filePath'];
  if (path is String && path.isNotEmpty) {
    return path.contains('/')
        ? path.substring(path.lastIndexOf('/') + 1)
        : path;
  }
  final pattern = input['pattern'];
  if (pattern is String && pattern.isNotEmpty) return '"$pattern"';
  final query = input['query'];
  if (query is String && query.isNotEmpty) return '"$query"';
  return '';
}
