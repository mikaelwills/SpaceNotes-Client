import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';

enum ChatImageSource { camera, library }

Future<ChatImageSource?> showChatImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ChatImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const ChatImageSourceSheet(),
  );
}

class ChatImageSourceSheet extends StatelessWidget {
  const ChatImageSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SpaceNotesTheme.bg,
        border: Border(
          top: BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 2,
              color: SpaceNotesTheme.hairlineStrong,
            ),
            _option(
              context,
              key: const ValueKey('chat_image_source_camera'),
              icon: Icons.photo_camera_outlined,
              label: 'Camera',
              source: ChatImageSource.camera,
            ),
            _option(
              context,
              key: const ValueKey('chat_image_source_library'),
              icon: Icons.photo_library_outlined,
              label: 'Photo library',
              source: ChatImageSource.library,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required ChatImageSource source,
  }) {
    return InkWell(
      key: key,
      onTap: () => Navigator.of(context).pop(source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: SpaceNotesTheme.accent),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(color: SpaceNotesTheme.fg, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
