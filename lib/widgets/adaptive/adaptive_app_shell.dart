import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../desktop/desktop_shell.dart';
import '../incoming_call_banner.dart';
import '../main_scaffold.dart';
import 'platform_utils.dart';

class AdaptiveAppShell extends ConsumerWidget {
  final Widget child;

  const AdaptiveAppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        AdaptiveBuilder(
          mobileBuilder: (context) => MainScaffold(child: child),
          desktopBuilder: (context) => DesktopShell(child: child),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(child: IncomingCallBanner()),
        ),
      ],
    );
  }
}
