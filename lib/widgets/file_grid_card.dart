import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/space_file.dart';
import '../theme/spacenotes_theme.dart';
import '../providers/file_transfer_providers.dart';
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
  });

  final SpaceFile file;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  bool get _isImage => FileTypeRegistry.forFile(file).icon == Icons.image_outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: SpaceNotesTheme.card,
          border: Border.all(color: SpaceNotesTheme.hairline, width: 1),
        ),
        child: _isImage
            ? _ImageCardBody(file: file)
            : _StandardCardBody(file: file, index: index),
      ),
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
      child: Stack(
        children: [
          const _CloudPlaceholder(),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              file.name,
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
      ),
    );
  }
}

class _StandardCardBody extends StatelessWidget {
  const _StandardCardBody({required this.file, required this.index});

  final SpaceFile file;
  final int index;

  @override
  Widget build(BuildContext context) {
    final preview = file.content.trim();
    final hasPreview = preview.isNotEmpty;

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
              Icon(
                FileTypeRegistry.forFile(file).icon,
                size: 13,
                color: SpaceNotesTheme.dim,
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
        if (path == null) return const _CloudPlaceholder();
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _CloudPlaceholder(),
        );
      },
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
