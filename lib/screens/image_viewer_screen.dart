import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  bool _loading = false;
  double _progress = 0;
  String? _error;
  String? _localPath;

  Future<void> _ensureAvailable(String remotePath, int expectedSize) async {
    debugLogger.info(
      'IMAGE_VIEWER',
      'ensureAvailable called',
      'remotePath=$remotePath expectedSize=$expectedSize',
    );

    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    final state = await store.stateFor(remotePath);
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
      _error = null;
    });

    final service = ref.read(fileTransferServiceProvider);
    try {
      debugLogger.info('IMAGE_VIEWER', 'Calling downloadFile', 'remotePath=$remotePath -> localPath=$localPath');
      await service.downloadFile(
        remotePath,
        localPath,
        onProgress: (received, total) {
          if (total > 0 && mounted) setState(() => _progress = received / total);
        },
      );
      final actualSize = await File(localPath).exists() ? await File(localPath).length() : -1;
      debugLogger.info(
        'IMAGE_VIEWER',
        'downloadFile returned, verifying',
        'expectedSize=$expectedSize actualLocalFileSize=$actualSize',
      );
      final verified =
          await store.markCompleteIfVerified(remotePath, localPath, expectedSize);
      debugLogger.info('IMAGE_VIEWER', verified ? 'Verified and marked complete' : 'Verification FAILED (size mismatch or missing file)', remotePath);
      if (mounted) setState(() => _localPath = localPath);
    } catch (e, st) {
      debugLogger.error('IMAGE_VIEWER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      ref.invalidate(downloadStateProvider(remotePath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));

    if (file == null) {
      return const Scaffold(
        backgroundColor: SpaceNotesTheme.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final remotePath = file.path;

    if (_localPath == null && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureAvailable(remotePath, file.size.toInt());
      });
    }

    return Scaffold(
      backgroundColor: SpaceNotesTheme.bg,
      appBar: AppBar(
        backgroundColor: SpaceNotesTheme.bg,
        title: Text(file.name, style: const TextStyle(color: SpaceNotesTheme.fg, fontSize: 15)),
      ),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))
              : _localPath != null
                  ? InteractiveViewer(
                      child: Image.file(File(_localPath!)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
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
                    ),
        ),
      ),
    );
  }
}
