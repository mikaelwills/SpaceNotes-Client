import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive/platform_utils.dart';
import '../widgets/mobile_bottom_input_bar.dart';

/// Enum to track which view is currently active
enum HomeViewType { folders, chat, note }

/// Provider to track the current folder path for bottom bar context
final currentFolderPathProvider = StateProvider<String>((ref) => '');

/// Provider to track if we're viewing a note
final currentNotePathProvider = StateProvider<String?>((ref) => null);

/// HomeScreen shell that provides the shared bottom input area (mobile only)
class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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
