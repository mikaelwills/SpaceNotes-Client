import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/space_file.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/file_transfer_providers.dart';
import '../providers/thumbnail_cache_provider.dart';
import '../services/debug_logger.dart';
import '../services/local_download_store.dart';
import '../file_types/file_type_registry.dart';

/// One file card for the grid view (recent notes, folder contents).
///
/// A downloaded image shows its 1:1 thumbnail edge-to-edge and nothing else
/// — no name, no index. A not-yet-downloaded image shows the name and a
/// cloud icon in the same reserved square; tapping it downloads and opens
/// (handled by the viewer screen itself). Every other file type keeps the
/// index/icon header, name, and text preview.
class FileGridCard extends ConsumerWidget {
  const FileGridCard({
    super.key,
    required this.file,
    required this.index,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectable = false,
  });

  final SpaceFile file;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Ticked, and part of whatever a bulk action will apply to.
  final bool selected;

  /// Select mode is on, so the card shows an empty tick rather than nothing.
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onLongPress,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: SpaceNotesTheme.card,
              border: Border.all(
                color: selected
                    ? SpaceNotesTheme.primary
                    : _usesSquareCard
                        ? SpaceNotesTheme.hairline
                        : FileTypeRegistry.forFile(file)
                            .color
                            .withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
            ),
            child: _usesSquareCard
                ? _ImageCardBody(file: file)
                : _StandardCardBody(file: file, index: index),
          ),
          if (selectable)
            Positioned(
              top: 6,
              right: 6,
              child: _SelectionTick(selected: selected),
            ),
        ],
      ),
    );
  }

  bool get _usesSquareCard {
    final icon = FileTypeRegistry.forFile(file).icon;
    if (icon == Icons.image_outlined) return true;
    return icon == Icons.videocam_outlined && file.hasThumbnail;
  }
}

/// Reads as a checkbox on both an image thumbnail and a plain card, so it
/// carries its own opaque ground rather than relying on what is behind it.
class _SelectionTick extends StatelessWidget {
  const _SelectionTick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected
            ? SpaceNotesTheme.primary
            : SpaceNotesTheme.bg.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? SpaceNotesTheme.primary : SpaceNotesTheme.dim,
          width: 1,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: SpaceNotesTheme.bg)
          : null,
    );
  }
}

class _ImageCardBody extends ConsumerWidget {
  const _ImageCardBody({required this.file});

  final SpaceFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadStateProvider(file.path));

    return state.when(
      data: (s) => s == DownloadState.complete
          ? AspectRatio(
              aspectRatio: 1,
              child: _ThumbnailImage(file: file),
            )
          : _NotDownloadedImageCard(file: file),
      loading: () => _NotDownloadedImageCard(file: file),
      error: (_, __) => _NotDownloadedImageCard(file: file),
    );
  }
}

class _NotDownloadedImageCard extends StatelessWidget {
  const _NotDownloadedImageCard({required this.file});

  final SpaceFile file;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: _ThumbnailFallback(file: file),
    );
  }
}

class _StandardCardBody extends ConsumerWidget {
  const _StandardCardBody({required this.file, required this.index});

  final SpaceFile file;
  final int index;

  static const _previewCharLimit = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = file.content.trim();
    final preview = trimmed.length > _previewCharLimit
        ? trimmed.substring(0, _previewCharLimit)
        : trimmed;
    final hasPreview = preview.isNotEmpty;
    final handler = FileTypeRegistry.forFile(file);
    final typeColor = handler.color;
    final downloadState = handler.isOffloadable
        ? ref.watch(downloadStateProvider(file.path)).valueOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                index.toString().padLeft(3, '0'),
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 9,
                  color: SpaceNotesTheme.dim,
                  letterSpacing: 0.6,
                ),
              ),
              Row(
                children: [
                  if (downloadState == DownloadState.complete) ...[
                    const Icon(
                      Icons.arrow_circle_down,
                      size: 11,
                      color: SpaceNotesTheme.online,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Icon(
                    handler.icon,
                    size: 13,
                    color: typeColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            file.name,
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontSans,
              fontSize: 15,
              color: SpaceNotesTheme.fg,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasPreview) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
            child: Text(
              preview,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 12,
                color: SpaceNotesTheme.muted,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const SizedBox(height: 12),
      ],
    );
  }
}

class _ThumbnailImage extends ConsumerWidget {
  const _ThumbnailImage({required this.file});

  final SpaceFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(localDownloadStoreProvider);
    return FutureBuilder<String>(
      future: store.localPathFor(file.path),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) {
          return _ThumbnailFallback(file: file);
        }
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ThumbnailFallback(file: file),
        );
      },
    );
  }
}

/// Shown for a not-yet-downloaded file: a small server-generated preview if
/// one is available, else the plain cloud placeholder — same as before this
/// feature existed.
class _ThumbnailFallback extends ConsumerStatefulWidget {
  const _ThumbnailFallback({required this.file});

  final SpaceFile file;

  @override
  ConsumerState<_ThumbnailFallback> createState() => _ThumbnailFallbackState();
}

class _ThumbnailFallbackState extends ConsumerState<_ThumbnailFallback> {
  @override
  void initState() {
    super.initState();
    debugLogger.debug(
      'THUMB',
      'Card built',
      'path=${widget.file.path} id=${widget.file.id} hasThumbnail=${widget.file.hasThumbnail}',
    );
    if (widget.file.hasThumbnail) {
      ref.read(thumbnailCacheProvider.notifier).request(widget.file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (widget.file.hasThumbnail) {
      ref.watch(thumbnailCacheProvider);
      bytes = ref.read(thumbnailCacheProvider.notifier).touch(widget.file.id);
    }

    if (bytes == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const _CloudPlaceholder(),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              widget.file.name,
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontSans,
                fontSize: 12,
                color: SpaceNotesTheme.muted,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return SizedBox.expand(
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugLogger.error('THUMB', 'Image.memory decode failed', '${widget.file.id} error=$error');
          return const _CloudPlaceholder();
        },
      ),
    );
  }
}

class _CloudPlaceholder extends StatelessWidget {
  const _CloudPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: SpaceNotesTheme.bgAlt,
      child: Center(
        child: Icon(
          Icons.cloud_outlined,
          size: 28,
          color: SpaceNotesTheme.dim,
        ),
      ),
    );
  }
}
