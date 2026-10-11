import 'package:flutter/material.dart';

import '../theme/spacenotes_theme.dart';

enum ChatImageSource { camera, library }

Future<ChatImageSource?> showChatImageSourceDialog(BuildContext context) {
  return showDialog<ChatImageSource>(
    context: context,
    builder: (_) => const ChatImageSourceDialog(),
  );
}

class ChatImageSourceDialog extends StatelessWidget {
  const ChatImageSourceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpaceNotesTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: SpaceNotesTheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      title: const Text(
        'Add image',
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: SpaceNotesTheme.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
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
    return ListTile(
      key: key,
      leading: Icon(icon, color: SpaceNotesTheme.primary),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: SpaceNotesTheme.text,
        ),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}
