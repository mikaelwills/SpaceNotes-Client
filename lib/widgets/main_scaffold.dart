import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';
import 'mobile_nav_bar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceNotesTheme.background,
      body: Column(
        children: [
          const MobileNavBar(),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}