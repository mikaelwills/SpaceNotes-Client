import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/call_providers.dart';
import '../desktop/desktop_shell.dart';
import '../main_scaffold.dart';
import 'platform_utils.dart';

class AdaptiveAppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdaptiveAppShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AdaptiveAppShell> createState() => _AdaptiveAppShellState();
}

class _AdaptiveAppShellState extends ConsumerState<AdaptiveAppShell> {
  bool _navigatedToIncoming = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingCallProvider, (prev, next) {
      next.whenData((session) {
        if (session != null && !_navigatedToIncoming && mounted) {
          _navigatedToIncoming = true;
          context.goNamed('incoming-call');
        } else if (session == null) {
          _navigatedToIncoming = false;
        }
      });
    });

    return AdaptiveBuilder(
      mobileBuilder: (context) => MainScaffold(child: widget.child),
      desktopBuilder: (context) => DesktopShell(child: widget.child),
    );
  }
}
