import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../screens/online_users_screen.dart';
import '../theme/spacenotes_theme.dart';

class IncomingCallBanner extends ConsumerWidget {
  const IncomingCallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(incomingCallProvider);
    if (session == null) return const SizedBox.shrink();

    final users = ref.watch(connectedUsersProvider);
    final caller = users.where((u) => u.identity == session.caller).firstOrNull;
    final callerName = caller?.name;
    final displayName = (callerName != null && callerName.isNotEmpty)
        ? callerName
        : session.caller.toHexString.substring(0, 12);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: SpaceNotesTheme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Incoming video call',
                    style: TextStyle(
                      color: SpaceNotesTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final callService = ref.read(callServiceProvider);
                final repo = ref.read(notesRepositoryProvider);
                callService.setClient(repo.client);
                callService.endCall(session.sessionId);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SpaceNotesTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end_rounded,
                    color: SpaceNotesTheme.error, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                final callService = ref.read(callServiceProvider);
                final repo = ref.read(notesRepositoryProvider);
                callService.setClient(repo.client);
                callService.acceptCall(session.sessionId);
                context.goNamed('call', pathParameters: {
                  'sessionId': session.sessionId.toString()
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
