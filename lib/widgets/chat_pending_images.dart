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
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  final List<PendingChatImage> images;
  final ValueChanged<int> onRemove;
  final bool sending;
  final EdgeInsetsGeometry padding;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && !sending) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
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
          if (images.isNotEmpty)
            SizedBox(
              height: _size,
              child: ListView.separated(
                key: const ValueKey('chat_pending_images'),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _Thumb(
                  image: images[index],
                  size: _size,
                  dimmed: sending,
                  onRemove: sending ? null : () => onRemove(index),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.image,
    required this.size,
    required this.dimmed,
    required this.onRemove,
  });

  final PendingChatImage image;
  final double size;
  final bool dimmed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(SpaceNotesTheme.radiusXs),
              child: Image.memory(
                image.bytes,
                fit: BoxFit.cover,
                cacheWidth: pixels,
                gaplessPlayback: true,
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
