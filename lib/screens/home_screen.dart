import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../file_types/file_type_registry.dart';
import '../providers/notes_providers.dart';
import '../platform/capabilities.dart';
import '../providers/preferences_provider.dart';
import '../widgets/adaptive/nav_cycle.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/audio_mini_bar.dart';
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

    final childHostsDock = _childHostsDock(context, ref);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            cycleNav(
              context,
              agentsEnabled: ref.read(agentsEnabledProvider),
              passwordsEnabled: ref.read(passwordsEnabledProvider) &&
                  Capabilities.canManagePasswords,
            ),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
            ref.read(mobileInputFocusNodeProvider).requestFocus(),
      },
      child: FocusScope(
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!childHostsDock) const AudioMiniBar(),
                    const MobileBottomInputBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _childHostsDock(BuildContext context, WidgetRef ref) {
    const filePrefix = '/notes/note/';
    final path = GoRouterState.of(context).uri.path;
    if (!path.startsWith(filePrefix)) return false;
    final file = ref.watch(fileByIdProvider(path.substring(filePrefix.length)));
    if (file == null) return false;
    return FileTypeRegistry.forFile(file).hostsMobileDock;
  }
}
