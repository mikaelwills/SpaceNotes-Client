import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/message.dart';
import '../generated/permission_request.dart';
import '../generated/question_request.dart';
import '../generated/tool_event.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'markdown_styles.dart';
import 'primitives/primitives.dart';

Widget chatItemToWidget(BuildContext context, ChatItem item) {
  return switch (item) {
    ChatMessageItem(:final message) => TerminalMessage(message: message),
    ChatToolItem(:final event) => ToolEventRow(event: event),
    ChatPermissionItem(:final request) => PermissionRow(request: request),
    ChatQuestionItem(:final request) => QuestionRow(request: request),
  };
}

Key chatItemKey(ChatItem item) {
  return switch (item) {
    ChatMessageItem(:final message) => ValueKey('msg:${message.id}'),
    ChatToolItem(:final event) => ValueKey('tool:${event.id}'),
    ChatPermissionItem(:final request) => ValueKey('perm:${request.id}'),
    ChatQuestionItem(:final request) => ValueKey('question:${request.id}'),
  };
}

class TerminalMessage extends StatelessWidget {
  final Message message;

  const TerminalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') return _buildUserMessage(context);
    return _buildAssistantMessage(context);
  }

  Widget _buildUserMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 14, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTextWidth = (constraints.maxWidth - 14) * 0.82;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                  child: Container(
                    padding: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: SpaceNotesTheme.accent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _time,
                          style: const TextStyle(
                            fontFamily: SpaceNotesTheme.fontMono,
                            fontSize: 10,
                            color: SpaceNotesTheme.dim,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          message.text,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: SpaceNotesTheme.fontSans,
                            fontSize: 15,
                            color: SpaceNotesTheme.fg,
                            height: 1.55,
                          ),
                        ),
                        _SendStatusTick(message: message),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 32, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '—',
                style: TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: SpaceNotesTheme.dim,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.source.toUpperCase(),
                style: TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: _sourceColor,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _time,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectionArea(
            child: MarkdownBody(
              data: message.text,
              selectable: false,
              fitContent: false,
              shrinkWrap: true,
              styleSheet: SpaceMarkdownStyles.chatAssistant(context),
              builders: {'table': TableAsBulletsBuilder()},
              softLineBreak: true,
            ),
          ),
        ],
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
      case 'error':
        return SpaceNotesTheme.error;
      case 'notice':
      case 'mcp':
      case 'hook':
        return SpaceNotesTheme.accent2;
      default:
        return SpaceNotesTheme.muted;
    }
  }
}

class _SendStatusTick extends ConsumerWidget {
  final Message message;

  const _SendStatusTick({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      chatSendStatusProvider.select((m) => m[message.id]?.status),
    );
    if (status == null) return const SizedBox.shrink();

    final (icon, color, tappable) = switch (status) {
      ChatSendStatus.pending => (
          Icons.schedule,
          SpaceNotesTheme.dim,
          false,
        ),
      ChatSendStatus.sent => (
          Icons.check,
          SpaceNotesTheme.dim,
          false,
        ),
      ChatSendStatus.failed => (
          Icons.error_outline,
          SpaceNotesTheme.error,
          true,
        ),
    };

    final tick = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          if (status == ChatSendStatus.failed) ...[
            const SizedBox(width: 5),
            const Text(
              'failed · tap to retry',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 10,
                color: SpaceNotesTheme.error,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );

    if (!tappable) return tick;
    return InkWell(
      onTap: () {
        ref.read(chatSendStatusProvider.notifier).clear(message.id);
        sendChatMessage(
          ref,
          sessionId: message.sessionId,
          text: message.text,
        );
      },
      child: tick,
    );
  }
}

class ToolEventRow extends StatelessWidget {
  final ToolEvent event;

  const ToolEventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final detail = _parseDetail(event.detail);
    final summary = _summarize(detail);
    final label = summary.isEmpty ? event.tool : '${event.tool}  $summary';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SnToolLine(
              label: label,
              status: SnToolStatus.done,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _time,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.dim,
              letterSpacing: 0.5,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 32, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border: Border.all(color: SpaceNotesTheme.hairlineStrong, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PERMISSION',
                  style: TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 10,
                    color: SpaceNotesTheme.dim,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  request.tool,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontSans,
                  fontSize: 14,
                  color: SpaceNotesTheme.fg,
                  height: 1.5,
                ),
              ),
            ],
            if (inputPreview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                inputPreview.length > 160
                    ? '${inputPreview.substring(0, 160)}…'
                    : inputPreview,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 11,
                  color: SpaceNotesTheme.muted,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                SnButton(
                  label: 'allow',
                  accent: SpaceNotesTheme.accent,
                  variant: SnButtonVariant.outline,
                  onPressed: () => respondToPermission(
                    ref,
                    requestId: request.id,
                    allow: true,
                  ),
                ),
                const SizedBox(width: 10),
                SnButton(
                  label: 'deny',
                  variant: SnButtonVariant.outline,
                  onPressed: () => respondToPermission(
                    ref,
                    requestId: request.id,
                    allow: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionRow extends ConsumerStatefulWidget {
  final QuestionRequest request;

  const QuestionRow({super.key, required this.request});

  @override
  ConsumerState<QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends ConsumerState<QuestionRow> {
  final Set<String> _selected = {};

  List<String> get _options {
    try {
      final decoded = jsonDecode(widget.request.options);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }

  void _submit(List<String> labels) {
    if (labels.isEmpty) return;
    respondToQuestion(ref, requestId: widget.request.id, labels: labels);
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.request.multiSelect;
    final header = widget.request.header;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 32, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'QUESTION',
                style: TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (header.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  header,
                  style: const TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    color: SpaceNotesTheme.fg,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.request.question,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 14,
              color: SpaceNotesTheme.fg,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final label in _options) _option(label, multi),
          if (multi) ...[
            const SizedBox(height: 10),
            SnButton(
              label: 'submit',
              accent: SpaceNotesTheme.accent,
              variant: SnButtonVariant.outline,
              onPressed: () => _submit(_selected.toList()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _option(String label, bool multi) {
    final checked = _selected.contains(label);
    return InkWell(
      onTap: () {
        if (multi) {
          setState(() {
            if (checked) {
              _selected.remove(label);
            } else {
              _selected.add(label);
            }
          });
        } else {
          _submit([label]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              multi ? (checked ? '[x] ' : '[ ] ') : '› ',
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 14,
                color: checked ? SpaceNotesTheme.accent : SpaceNotesTheme.dim,
                height: 1.45,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontSans,
                  fontSize: 14,
                  color: SpaceNotesTheme.fg,
                  height: 1.45,
                ),
              ),
            ),
          ],
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
    return command.length > 60 ? '${command.substring(0, 60)}…' : command;
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
