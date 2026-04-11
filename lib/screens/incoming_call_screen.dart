import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../generated/call_session.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../screens/online_users_screen.dart';
import '../theme/spacenotes_theme.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    if (_accepted) {
      return const Scaffold(backgroundColor: SpaceNotesTheme.background);
    }

    final session = ref.watch(incomingCallProvider);
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_accepted) GoRouter.of(context).go('/notes');
      });
      return const Scaffold(backgroundColor: SpaceNotesTheme.background);
    }

    return _IncomingCallBody(
      session: session,
      onAccepted: () => setState(() => _accepted = true),
    );
  }
}

class _IncomingCallBody extends ConsumerWidget {
  final CallSession session;
  final VoidCallback? onAccepted;

  const _IncomingCallBody({required this.session, this.onAccepted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(connectedUsersProvider);
    final caller = users.where((u) => u.identity == session.caller).firstOrNull;
    final callerName = caller?.name;
    final displayName = (callerName != null && callerName.isNotEmpty)
        ? callerName
        : session.caller.toHexString.substring(0, 12);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.green, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              displayName,
              style: const TextStyle(
                color: SpaceNotesTheme.text,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Incoming Video Call',
              style: TextStyle(
                color: SpaceNotesTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CallActionButton(
                  icon: Icons.call_end_rounded,
                  color: SpaceNotesTheme.error,
                  label: 'Decline',
                  onTap: () {
                    final callService = ref.read(callServiceProvider);
                    final repo = ref.read(notesRepositoryProvider);
                    callService.setClient(repo.client);
                    callService.endCall(session.sessionId);
                  },
                ),
                const SizedBox(width: 64),
                _CallActionButton(
                  icon: Icons.videocam_rounded,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: () {
                    onAccepted?.call();
                    final callService = ref.read(callServiceProvider);
                    final repo = ref.read(notesRepositoryProvider);
                    callService.setClient(repo.client);
                    callService.acceptCall(session.sessionId);
                    context.goNamed('call', pathParameters: {
                      'sessionId': session.sessionId.toString()
                    });
                  },
                ),
              ],
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: SpaceNotesTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
