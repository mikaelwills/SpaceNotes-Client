import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/mobile_bottom_input_bar.dart';

enum HomeViewType { folders, chat, note, agents, agentChat }

/// HomeScreen shell that provides the shared bottom input area (mobile only)
class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the recently-touched agents warm in the offline cache for the
    // whole time the app shell is mounted.
    ref.watch(warmRecentAgentsProvider);

    if (PlatformUtils.isDesktopLayout(context)) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(child: child),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MobileBottomInputBar(),
        ),
      ],
    );
  }
}
