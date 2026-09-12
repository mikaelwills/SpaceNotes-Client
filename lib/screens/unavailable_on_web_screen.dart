import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';

/// Shown instead of a file viewer on web. Downloads need sqflite +
/// path_provider for the on-device cache, neither of which exists in a
/// browser, so opening a file there would throw rather than degrade.
class UnavailableOnWebScreen extends StatelessWidget {
  const UnavailableOnWebScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_outlined,
              size: 32,
              color: SpaceNotesTheme.dim,
            ),
            SizedBox(height: 16),
            Text(
              'Files are not available in the browser',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 15,
                color: SpaceNotesTheme.fg,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Open this file in the desktop or mobile app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 13,
                color: SpaceNotesTheme.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
