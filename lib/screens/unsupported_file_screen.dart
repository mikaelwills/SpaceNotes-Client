import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';

class UnsupportedFileScreen extends ConsumerStatefulWidget {
  const UnsupportedFileScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<UnsupportedFileScreen> createState() =>
      _UnsupportedFileScreenState();
}

class _UnsupportedFileScreenState extends ConsumerState<UnsupportedFileScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (file == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final remotePath = file.path;
    final downloadState = ref.watch(downloadStateProvider(remotePath));

    return ColoredBox(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                color: SpaceNotesTheme.dim,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                file.name,
                style: const TextStyle(
                  color: SpaceNotesTheme.fg,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '.${file.extension} viewer not implemented',
                style:
                    const TextStyle(color: SpaceNotesTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_downloading)
                Column(
                  children: [
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(value: _progress),
                    ),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: SpaceNotesTheme.muted, fontSize: 12)),
                  ],
                )
              else
                downloadState.when(
                  data: (state) => switch (state) {
                    DownloadState.complete => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _StatusPill(
                            icon: Icons.check_circle_outline,
                            label: 'Downloaded',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final localPath = await ref
                                  .read(localDownloadStoreProvider)
                                  .localPathFor(remotePath);
                              await SharePlus.instance.share(
                                ShareParams(files: [XFile(localPath)]),
                              );
                            },
                            icon: const Icon(Icons.ios_share, size: 16),
                            label: const Text('Share'),
                          ),
                        ],
                      ),
                    DownloadState.partial => OutlinedButton.icon(
                        onPressed: () => _download(remotePath),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Resume download'),
                      ),
                    DownloadState.notDownloaded => OutlinedButton.icon(
                        onPressed: () => _download(remotePath),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Download'),
                      ),
                  },
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => OutlinedButton.icon(
                    onPressed: () => _download(remotePath),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download(String remotePath) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final service = ref.read(fileTransferServiceProvider);
    final file = ref.read(fileByIdProvider(widget.fileId));
    final expectedSize = file?.size.toInt() ?? 0;

    try {
      await service.ensureDownloaded(
        remotePath,
        expectedSize,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
    } catch (e) {
      debugLogger.error(
          'DOWNLOAD', 'Download UI error: $remotePath', e.toString());
      if (mounted) setState(() => _error = 'Download failed: $e');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        ref.invalidate(downloadStateProvider(remotePath));
      }
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: SpaceNotesTheme.muted),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: SpaceNotesTheme.muted, fontSize: 13)),
      ],
    );
  }
}
