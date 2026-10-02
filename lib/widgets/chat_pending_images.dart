import 'package:flutter/material.dart';

import '../services/chat_attachments.dart';
import '../theme/spacenotes_theme.dart';
import 'primitives/primitives.dart';

class ChatPendingImages extends StatelessWidget {
  const ChatPendingImages({
    super.key,
    required this.images,
    required this.onRemove,
    this.sending = false,
  });

  final List<PendingChatImage> images;
  final ValueChanged<int> onRemove;
  final bool sending;

  static const _height = 120.0;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && !sending) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: _height,
              child: ListView.separated(
                key: const ValueKey('chat_pending_images'),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _Thumb(
                  key: ValueKey('chat_pending_image_$index'),
                  image: images[index],
                  height: _height,
                  dimmed: sending,
                  onRemove: sending ? null : () => onRemove(index),
                  removeKey: ValueKey('chat_pending_image_remove_$index'),
                ),
              ),
            ),
          if (sending)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: SpaceNotesTheme.accent,
                    ),
                  ),
                  SizedBox(width: 8),
                  SnUiText(
                    'uploading images…',
                    color: SpaceNotesTheme.dim,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.image,
    required this.height,
    required this.dimmed,
    required this.onRemove,
    required this.removeKey,
  });

  final PendingChatImage image;
  final double height;
  final bool dimmed;
  final VoidCallback? onRemove;
  final Key removeKey;

  @override
  Widget build(BuildContext context) {
    final pixels = (height * MediaQuery.devicePixelRatioOf(context)).round();
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: height * 0.5,
                maxWidth: height * 1.8,
              ),
              child: Image.memory(
                image.bytes,
                height: height,
                fit: BoxFit.cover,
                cacheHeight: pixels,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                key: removeKey,
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
