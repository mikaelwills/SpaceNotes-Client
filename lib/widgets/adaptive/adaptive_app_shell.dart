import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../desktop/desktop_shell.dart';
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
    return AdaptiveBuilder(
      mobileBuilder: (context) => MainScaffold(child: child),
      desktopBuilder: (context) => DesktopShell(child: child),
    );
  }
}
