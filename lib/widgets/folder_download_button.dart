import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../file_types/file_type_registry.dart';
import '../generated/space_file.dart';
import '../platform/capabilities.dart';
import '../providers/download_queue_provider.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../theme/spacenotes_theme.dart';

class FolderDownloadButton extends ConsumerWidget {
  const FolderDownloadButton({super.key, required this.files});

  final List<SpaceFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Capabilities.canDownloadFiles) return const SizedBox.shrink();

    final queue = ref.watch(downloadQueueProvider);
    final notifier = ref.read(downloadQueueProvider.notifier);

    if (queue.isActive) {
      return GestureDetector(
        key: const ValueKey('folder-download-cancel'),
        behavior: HitTestBehavior.opaque,
        onTap: notifier.cancel,
        child: Tooltip(
          message: 'Cancel downloads',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              '${queue.done}/${queue.total}',
              style: const TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 10,
                color: SpaceNotesTheme.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
    }

    final missing = [
      for (final file in files)
        if (FileTypeRegistry.forFileName(file.path.split('/').last).isOffloadable &&
            ref.watch(downloadStateProvider(file.path)).valueOrNull !=
                DownloadState.complete)
          file,
    ];
    final enabled = missing.isNotEmpty;

    return GestureDetector(
      key: const ValueKey('folder-download'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () => notifier.enqueue([
                for (final f in missing)
                  QueuedDownload(path: f.path, size: f.size.toInt()),
              ])
          : null,
      child: Tooltip(
        message: enabled
            ? 'Download ${missing.length} to this device'
            : 'All files on this device',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Icon(
            Icons.download_for_offline_outlined,
            size: 14,
            color: enabled ? SpaceNotesTheme.dim : SpaceNotesTheme.hairlineStrong,
          ),
        ),
      ),
    );
  }
}
