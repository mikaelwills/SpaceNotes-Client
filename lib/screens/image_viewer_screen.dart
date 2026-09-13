import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';
import '../utils/pops_when_file_deleted.dart';
import '../widgets/download_progress.dart';
import '../widgets/share_button.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen>
    with PopsWhenFileDeleted<ImageViewerScreen> {
  bool _loading = false;
  double _progress = 0;
  int _receivedBytes = 0;
  DateTime? _downloadStartedAt;
  String? _error;
  String? _localPath;

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (!trackFilePresence(file, context)) {
      return const Center(child: CircularProgressIndicator());
    }

    final remotePath = file!.path;

    if (_localPath == null && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureAvailable(remotePath, file.size.toInt());
      });
    }

    return ColoredBox(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))
                  : _localPath != null
                      ? InteractiveViewer(
                          child: Image.file(File(_localPath!)),
                        )
                      : DownloadProgress(
                          progress: _progress,
                          receivedBytes: _receivedBytes,
                          startedAt: _downloadStartedAt,
                          totalBytes: file.size.toInt(),
                        ),
            ),
            if (_localPath != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: ShareButton(localPath: _localPath!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureAvailable(String remotePath, int expectedSize) async {
    debugLogger.info(
      'IMAGE_VIEWER',
      'ensureAvailable called',
      'remotePath=$remotePath expectedSize=$expectedSize',
    );

    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    final state = await store.stateFor(remotePath, expectedSize: expectedSize);
    debugLogger.info(
      'IMAGE_VIEWER',
      'Local state checked',
      'localPath=$localPath state=$state',
    );

    if (state == DownloadState.complete) {
      debugLogger.info('IMAGE_VIEWER', 'Already complete, using cached file', localPath);
      if (mounted) setState(() => _localPath = localPath);
      return;
    }

    setState(() {
      _loading = true;
      _progress = 0;
      _receivedBytes = 0;
      _downloadStartedAt = DateTime.now();
      _error = null;
    });

    final service = ref.read(fileTransferServiceProvider);
    try {
      await service.ensureDownloaded(
        remotePath,
        expectedSize,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
              _receivedBytes = received;
            });
          }
        },
      );
      if (mounted) setState(() => _localPath = localPath);
    } catch (e, st) {
      debugLogger.error('IMAGE_VIEWER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      ref.invalidate(downloadStateProvider(remotePath));
    }
  }
}
