import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../providers/preferences_provider.dart';
import '../widgets/adaptive/nav_cycle.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/mobile_bottom_input_bar.dart';

enum HomeViewType { folders, chat, note, agents, agentChat, passwords }

/// HomeScreen shell that provides the shared bottom input area (mobile only)
class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isDesktopLayout(context)) {
      return child;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            cycleNav(context, agentsEnabled: ref.read(agentsEnabledProvider)),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
            ref.read(mobileInputFocusNodeProvider).requestFocus(),
      },
      child: FocusScope(
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MobileBottomInputBar(),
            ),
          ],
        ),
      ),
    );
  }
}
