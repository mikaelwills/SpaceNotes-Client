import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../models/permission_request.dart';
import '../theme/spacenotes_theme.dart';
import '../models/space_message.dart';
import '../models/message_part.dart';
import '../utils/text_sanitizer.dart';
import '../utils/tool_display_helper.dart';
import 'streaming_text.dart';

class TerminalMessage extends StatelessWidget {
  final SpaceMessage message;
  final bool isStreaming;

  const TerminalMessage({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.role == 'user') _buildUserMessage(context),
        if (message.role == 'assistant')
          _buildAssistantMessage(context),
      ],
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    final content = message.parts.isNotEmpty && message.parts.first.content != null
        ? message.parts.first.content!
        : '';

    return GestureDetector(
      onLongPress: () => _copyToClipboard(context, content),
      child: Row(
        children: [
          const Spacer(),
          if (message.sendStatus == MessageSendStatus.failed || message.sendStatus == MessageSendStatus.queued)
            _buildStatusIcons(context),
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
                    _safeTextSanitize(content, preserveMarkdown: false),
                    style: SpaceNotesTextStyles.terminal.copyWith(
                      color: SpaceNotesTheme.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formattedTime,
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
    final hasContent = message.parts.any((p) =>
      (p.content != null && p.content!.isNotEmpty) || p.type == 'tool'
    );

    final color = _sourceLabelColor;

    return GestureDetector(
      onLongPress: () => _copyToClipboard(context, message.content),
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
                  _formattedTime,
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    color: const Color(0xFF555555),
                    fontFamily: 'FiraCode',
                  ),
                ),
                if (message.project != null && message.project!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    message.project!.toUpperCase(),
                    style: SpaceNotesTextStyles.terminal.copyWith(
                      color: color,
                      fontFamily: 'FiraCode',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ],
            ),
            if (message.task != null && message.task!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  if (_statusIcon != null) ...[
                    _statusIcon!,
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      message.task!,
                      style: SpaceNotesTextStyles.terminal.copyWith(
                        color: SpaceNotesTheme.textSecondary,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            ...message.parts.map((part) => _buildMessagePart(part)),
            if (isStreaming && !hasContent)
              const _BlinkingCursor(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePart(MessagePart part) {
    final isPending = part.metadata?['pending_permission'] == true;
    if (isPending) return _buildPermissionPart(part);

    switch (part.type) {
      case 'text':
        return _buildTextPart(part);
      case 'tool':
        return _buildToolPart(part);
      case 'reasoning':
        return _buildReasoningPart(part);
      case 'retry':
        return _buildRetryPart(part);
      case 'step-start':
        return _buildStepStartPart(part);
      case 'step-finish':
        return _buildStepFinishPart(part);
      case 'subtask':
        return _buildSubtaskPart(part);
      default:
        return _buildTextPart(part);
    }
  }

  Widget _buildPermissionPart(MessagePart part) {
    final toolName = part.metadata?['tool_name'] ?? '';
    final inputPreview = part.metadata?['input_preview'] ?? '';
    final requestId = part.metadata?['request_id'] ?? '';
    final responded = part.metadata?['permission_responded'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: SpaceNotesTheme.warning),
              const SizedBox(width: 6),
              Text(
                toolName,
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (inputPreview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              inputPreview.length > 120 ? '${inputPreview.substring(0, 120)}...' : inputPreview,
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: const Color(0xFF999999),
                fontFamily: 'FiraCode',
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (responded != null)
            Text(
              responded == 'allow' ? '✓ Allowed' : '✗ Denied',
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: responded == 'allow' ? const Color(0xFF4CAF50) : SpaceNotesTheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: [
                Builder(builder: (ctx) => _PermissionButton(
                  label: 'Allow',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _respondToPermission(ctx, requestId, PermissionResponse.once),
                )),
                const SizedBox(width: 12),
                Builder(builder: (ctx) => _PermissionButton(
                  label: 'Deny',
                  color: SpaceNotesTheme.error,
                  onTap: () => _respondToPermission(ctx, requestId, PermissionResponse.reject),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextPart(MessagePart part) {
    if (part.content == null || part.content!.isEmpty) {
      return const SizedBox.shrink();
    }

    var content = part.content!;
    if (content.startsWith('✓') || content.startsWith('✗')) {
      final lines = content.split('\n');
      content = lines.skip(1).join('\n').trim();
      if (content.isEmpty) return const SizedBox.shrink();
    }
    final isLastPart = message.parts.last == part;
    final shouldStream = isStreaming && isLastPart && message.role == 'assistant';
    final contentColor = (message.sourceType == 'session' || message.sourceType == 'webhook')
        ? const Color(0xFF999999)
        : SpaceNotesTheme.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: shouldStream
          ? StreamingText(
              text: _safeTextSanitize(content, preserveMarkdown: true),
              style: SpaceNotesTextStyles.terminal.copyWith(color: contentColor),
              isStreaming: true,
              useMarkdown: true,
            )
          : MarkdownBody(
              data: _safeTextSanitize(content, preserveMarkdown: true),
              styleSheet: MarkdownStyleSheet(
                p: SpaceNotesTextStyles.terminal.copyWith(
                  color: contentColor,
                ),
                code: SpaceNotesTextStyles.code,
                codeblockDecoration: BoxDecoration(
                  color: SpaceNotesTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                codeblockPadding: const EdgeInsets.all(8),
                blockquote: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.textSecondary,
                ),
                blockquoteDecoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: SpaceNotesTheme.textSecondary,
                      width: 2,
                    ),
                  ),
                ),
                h1: SpaceNotesTextStyles.terminal.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                h2: SpaceNotesTextStyles.terminal.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h3: SpaceNotesTextStyles.terminal.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: SpaceNotesTextStyles.terminal,
                listIndent: 16,
              ),
              selectable: false,
            ),
    );
  }

  Widget _buildToolPart(MessagePart part) {
    final toolName = ToolDisplayHelper.getDisplayName(part);

    String state = 'pending';
    final stateValue = part.metadata?['state'];
    final statusValue = part.metadata?['status'];
    if (statusValue is String) {
      state = statusValue;
    } else if (statusValue is Map) {
      state = (statusValue['status'] ?? statusValue['state'] ?? 'pending')?.toString() ?? 'pending';
    } else if (stateValue is String) {
      state = stateValue;
    } else if (stateValue is Map) {
      state = (stateValue['status'] ?? stateValue['state'] ?? 'pending')?.toString() ?? 'pending';
    }

    String? error;
    final errorVal = part.metadata?['error'];
    if (errorVal is String) {
      error = errorVal;
    } else if (errorVal is Map) {
      error = errorVal['message'] ?? errorVal.toString();
    }
    error ??= part.metadata?['errorMessage'];
    error ??= part.metadata?['result']?['error'];

    if (state == 'error') {
      print('🔴 [ToolError] state=$state metadata=${part.metadata}');
    }

    final output = part.metadata?['output'] ??
                   part.metadata?['result']?['content'];

    String? commandDetails;

    Map<String, dynamic>? input;

    if (part.metadata?['input'] is Map) {
      input = part.metadata!['input'];
    }
    else if (stateValue is Map && stateValue['input'] is Map) {
      input = stateValue['input'];
    }

    if (input != null) {
      if (input['command'] != null) {
        commandDetails = input['command'] ?? '';
      } else if (input['query'] != null) {
        commandDetails = '"${input['query']}"';
      } else if (input['path'] != null || input['filePath'] != null) {
        commandDetails = input['path'] ?? input['filePath'] ?? '';
      } else if (input['pattern'] != null) {
        commandDetails = '"${input['pattern']}"';
      } else if (input['folder_path'] != null) {
        commandDetails = input['folder_path'] ?? '';
      } else if (input['id'] != null) {
        commandDetails = input['id'] ?? '';
      } else if (input['old_string'] != null) {
        final old = input['old_string'] ?? '';
        commandDetails = '"${old.length > 40 ? '${old.substring(0, 40)}...' : old}"';
      } else {
        final keys = input.keys.where((k) => k != 'type').toList();
        if (keys.length == 1) {
          final val = input[keys.first];
          if (val is String && val.length <= 60) {
            commandDetails = val;
          }
        }
      }
    }

    IconData icon;
    Color color;
    switch (state) {
      case 'pending':
        icon = Icons.schedule_outlined;
        color = SpaceNotesTheme.textSecondary;
        break;
      case 'running':
        icon = Icons.play_circle_outline;
        color = SpaceNotesTheme.primary;
        break;
      case 'completed':
        icon = Icons.check_circle_outline;
        color = SpaceNotesTheme.success;
        break;
      case 'error':
        icon = Icons.error_outline;
        color = SpaceNotesTheme.error;
        break;
      default:
        icon = Icons.circle_outlined;
        color = SpaceNotesTheme.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _safeTextSanitize(toolName, preserveMarkdown: false),
                        style: SpaceNotesTextStyles.terminal.copyWith(
                          color: color,
                          fontSize: 12,
                          fontWeight: state == 'running' ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (commandDetails != null && commandDetails.isNotEmpty) ...[
                        TextSpan(
                          text: ' ',
                          style: SpaceNotesTextStyles.terminal.copyWith(fontSize: 12),
                        ),
                        TextSpan(
                          text: _safeTextSanitize(commandDetails, preserveMarkdown: false),
                          style: SpaceNotesTextStyles.terminal.copyWith(
                            color: SpaceNotesTheme.text,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state == 'running') ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Error: ${_safeTextSanitize(error, preserveMarkdown: false)}',
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.error,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          if ((state == 'completed' || state == 'error') && output != null && output.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                output.length > 100
                    ? '${_safeTextSanitize(output.substring(0, 100), preserveMarkdown: false)}...'
                    : _safeTextSanitize(output, preserveMarkdown: false),
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasoningPart(MessagePart part) {
    final content = part.content;
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }

    final reasoningTokens = part.metadata?['reasoning_tokens'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology_outlined,
                size: 14,
                color: SpaceNotesTheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Thinking',
                style: SpaceNotesTextStyles.terminal.copyWith(
                  color: SpaceNotesTheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (reasoningTokens != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$reasoningTokens tokens',
                  style: SpaceNotesTextStyles.terminal.copyWith(
                    color: SpaceNotesTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _safeTextSanitize(content, preserveMarkdown: false),
            style: SpaceNotesTextStyles.terminal.copyWith(
              color: SpaceNotesTheme.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryPart(MessagePart part) {
    final attempt = part.metadata?['attempt'] ?? 1;
    final maxAttempts = part.metadata?['maxAttempts'] ?? 3;
    final reason = part.metadata?['reason'] ?? 'Unknown error';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.refresh,
            size: 14,
            color: SpaceNotesTheme.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Retrying ($attempt/$maxAttempts): ${_safeTextSanitize(reason, preserveMarkdown: false)}',
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.warning,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskPart(MessagePart part) {
    final description = part.content ?? 'Subtask';
    final status = part.metadata?['status'] ?? 'pending';

    IconData icon;
    Color color;
    switch (status) {
      case 'active':
        icon = Icons.play_circle_outline;
        color = SpaceNotesTheme.primary;
        break;
      case 'completed':
        icon = Icons.check_circle_outline;
        color = SpaceNotesTheme.success;
        break;
      default:
        icon = Icons.circle_outlined;
        color = SpaceNotesTheme.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _safeTextSanitize(description, preserveMarkdown: false),
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: status == 'active' ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStartPart(MessagePart part) {
    // Hide step start messages - they're just boundaries
    return const SizedBox.shrink();
  }

  Widget _buildStepFinishPart(MessagePart part) {
    // Show step finish with token info if available
    final tokens = part.metadata?['tokens'];

    if (tokens == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Row(
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 12,
            color: SpaceNotesTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '${tokens['input'] ?? 0}↓ ${tokens['output'] ?? 0}↑',
            style: SpaceNotesTextStyles.terminal.copyWith(
              color: SpaceNotesTheme.textSecondary,
              fontSize: 10,
            ),
          ),
          if (tokens['reasoning'] != null && tokens['reasoning'] > 0) ...[
            const SizedBox(width: 4),
            Text(
              '${tokens['reasoning']} 🧠',
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.secondary,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcons(BuildContext context) {
    final content = message.parts.isNotEmpty ? message.parts.first.content : null;

    if (content == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.sendStatus == MessageSendStatus.failed) ...[
            Tooltip(
              message: 'Failed to send. Tap to retry.',
              child: InkWell(
                onTap: () {
                  context.read<ChatBloc>().add(RetryMessage(content));
                },
                borderRadius: BorderRadius.circular(20),
                child: const Icon(
                  Icons.sync_problem,
                  color: SpaceNotesTheme.error,
                  size: 20,
                ),
              ),
            ),
          ] else if (message.sendStatus == MessageSendStatus.queued) ...[
            const Tooltip(
              message: 'Message queued for sending when online',
              child: Icon(
                Icons.schedule,
                color: SpaceNotesTheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Remove from queue',
              child: InkWell(
                onTap: () {
                  context.read<ChatBloc>().add(DeleteQueuedMessage(content));
                },
                borderRadius: BorderRadius.circular(20),
                child: const Icon(
                  Icons.close,
                  color: SpaceNotesTheme.error,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _formattedTime {
    final h = message.created.hour.toString().padLeft(2, '0');
    final m = message.created.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget? get _statusIcon {
    final content = message.content;
    if (content.startsWith('✓')) {
      return const Icon(Icons.check, size: 14, color: Color(0xFF4CAF50));
    }
    if (content.startsWith('✗')) {
      return const Icon(Icons.close, size: 14, color: SpaceNotesTheme.error);
    }
    return null;
  }

  Color get _sourceLabelColor {
    switch (message.sourceType) {
      case 'session':
        return SpaceNotesTheme.primary;
      case 'webhook':
        return const Color(0xFFF5E27A);
      default:
        return SpaceNotesTheme.error;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
  }

  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [TerminalMessage] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }

  void _respondToPermission(BuildContext context, String requestId, PermissionResponse response) {
    context.read<ChatBloc>().add(RespondToPermission(
      permissionId: message.id,
      response: response,
    ));
  }
}

class _PermissionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PermissionButton({required this.label, required this.color, required this.onTap});

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

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Text(
            '▌',
            style: SpaceNotesTextStyles.terminal.copyWith(
              color: SpaceNotesTheme.primary,
            ),
          ),
        );
      },
    );
  }
}