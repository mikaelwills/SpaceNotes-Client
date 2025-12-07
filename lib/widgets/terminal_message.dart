import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../theme/spacenotes_theme.dart';
import '../models/opencode_message.dart';
import '../models/message_part.dart';
import '../utils/text_sanitizer.dart';
import '../utils/tool_display_helper.dart';
import 'streaming_text.dart';

class TerminalMessage extends StatelessWidget {
  final OpenCodeMessage message;
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
        if (message.role == 'assistant') ...[
          const SizedBox(height: 16),
          _buildAssistantMessage(),
          const SizedBox(height: 16), // Space below assistant response
        ],
      ],
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    final content = message.parts.isNotEmpty && message.parts.first.content != null
        ? message.parts.first.content!
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0xFF444444),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
            child: Text(
              _safeTextSanitize(content, preserveMarkdown: false),
              style: SpaceNotesTextStyles.terminal,
            ),
          ),
        ),
        if (message.sendStatus == MessageSendStatus.failed || message.sendStatus == MessageSendStatus.queued)
          _buildStatusIcons(context),
      ],
    );
  }

  Widget _buildAssistantMessage() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: SpaceNotesTheme.secondary,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...message.parts.map((part) => _buildMessagePart(part)),
        ],
      ),
    );
  }

  Widget _buildMessagePart(MessagePart part) {
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

  Widget _buildTextPart(MessagePart part) {
    if (part.content == null || part.content!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLastPart = message.parts.last == part;
    final shouldStream = isStreaming && isLastPart && message.role == 'assistant';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: shouldStream
          ? StreamingText(
              text: _safeTextSanitize(part.content!, preserveMarkdown: true),
              style: SpaceNotesTextStyles.terminal,
              isStreaming: true,
              useMarkdown: true,
            )
          : MarkdownBody(
              data: _safeTextSanitize(part.content!, preserveMarkdown: true),
              styleSheet: MarkdownStyleSheet(
                p: SpaceNotesTextStyles.terminal,
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
              selectable: true,
            ),
    );
  }

  Widget _buildToolPart(MessagePart part) {
    final toolName = ToolDisplayHelper.getDisplayName(part);

    // State can be either a String directly or inside a Map
    String state = 'pending';
    final stateValue = part.metadata?['state'];
    if (stateValue is String) {
      state = stateValue;
    } else if (stateValue is Map) {
      // If state is a Map, look for common status fields
      state = (stateValue['status'] ?? stateValue['state'] ?? 'pending') as String;
    }

    final error = part.metadata?['error'] as String?;
    final output = part.metadata?['output'] as String?;

    // Extract command/args for bash and other tools
    String? commandDetails;

    // Try to get input from various locations in the metadata
    Map<String, dynamic>? input;

    // First try: input is directly in metadata
    if (part.metadata?['input'] is Map) {
      input = part.metadata!['input'] as Map<String, dynamic>;
    }
    // Second try: input is inside state map
    else if (stateValue is Map && stateValue['input'] is Map) {
      input = stateValue['input'] as Map<String, dynamic>;
    }

    if (input != null) {
      // For bash commands, show the actual command
      if (input['command'] != null) {
        commandDetails = input['command'] as String;
      }
      // For file operations, show the path
      else if (input['path'] != null || input['filePath'] != null) {
        commandDetails = (input['path'] ?? input['filePath']) as String;
      }
      // For other operations, try to get a meaningful detail
      else if (input['pattern'] != null) {
        commandDetails = input['pattern'] as String;
      }
    }

    // Determine icon and color based on state
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
          // Tool execution line with icon
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
          // Show error message if present
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
          // Show output preview if present and completed
          if (state == 'completed' && output != null && output.isNotEmpty) ...[
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

    final reasoningTokens = part.metadata?['reasoning_tokens'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: SpaceNotesTheme.secondary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
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
            const SizedBox(height: 8),
            Text(
              _safeTextSanitize(content, preserveMarkdown: false),
              style: SpaceNotesTextStyles.terminal.copyWith(
                color: SpaceNotesTheme.text,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryPart(MessagePart part) {
    final attempt = part.metadata?['attempt'] as int? ?? 1;
    final maxAttempts = part.metadata?['maxAttempts'] as int? ?? 3;
    final reason = part.metadata?['reason'] as String? ?? 'Unknown error';

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
    final status = part.metadata?['status'] as String? ?? 'pending';

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
    final tokens = part.metadata?['tokens'] as Map<String, dynamic>?;

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

  /// Safe text sanitization with fallback handling
  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [TerminalMessage] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }

  Widget _buildStatusIcons(BuildContext context) {
    final content = message.parts.isNotEmpty ? message.parts.first.content : null;
    
    if (content == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-specific primary icon
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
            // Delete button for queued messages
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
}