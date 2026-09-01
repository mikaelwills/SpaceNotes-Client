import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';
import 'adaptive/platform_utils.dart';
import 'mobile_nav_bar.dart';
import 'upload_progress_bar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final needsTrafficLightInset = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        !PlatformUtils.isDesktopLayout(context);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.background,
      body: Column(
        children: [
          if (needsTrafficLightInset) const SizedBox(height: 13),
          const MobileNavBar(),
          const UploadProgressBar(),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
