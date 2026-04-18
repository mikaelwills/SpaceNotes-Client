import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../theme/spacenotes_theme.dart';
import 'tool_status_row.dart';

class ConnectionStatusRow extends ConsumerWidget {
  const ConnectionStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetSession = ref.watch(targetSessionProvider);
    final activity = ref.watch(sessionActivityProvider(targetSession));

    final displayName = targetSession
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: SpaceNotesTextStyles.terminal.copyWith(
              fontSize: 13,
              color: targetSession != defaultTargetSession
                  ? SpaceNotesTheme.primary
                  : SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          ToolStatusRow(
            activity: activity,
            padding: const EdgeInsets.only(top: 2),
          ),
        ],
      ),
    );
  }
}
