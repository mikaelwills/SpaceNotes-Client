import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
  int _receivedBytes = 0;
  DateTime? _downloadStartedAt;
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
      _receivedBytes = 0;
      _downloadStartedAt = DateTime.now();
      _error = null;
    });

    final service = ref.read(fileTransferServiceProvider);
    try {
      debugLogger.info('IMAGE_VIEWER', 'Calling downloadFile', 'remotePath=$remotePath -> localPath=$localPath');
      await service.downloadFile(
        remotePath,
        localPath,
        expectedSize: expectedSize,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
              _receivedBytes = received;
            });
          }
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
      return const Center(child: CircularProgressIndicator());
    }

    final remotePath = file.path;

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
                      : _DownloadProgress(
                          progress: _progress,
                          receivedBytes: _receivedBytes,
                          startedAt: _downloadStartedAt,
                        ),
            ),
            if (_localPath != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: _ShareButton(localPath: _localPath!),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({
    required this.progress,
    required this.receivedBytes,
    required this.startedAt,
  });

  final double progress;
  final int receivedBytes;
  final DateTime? startedAt;

  String get _speedLabel {
    if (startedAt == null || receivedBytes <= 0) return '';
    final elapsed = DateTime.now().difference(startedAt!).inMilliseconds;
    if (elapsed <= 0) return '';
    final bytesPerSecond = receivedBytes / (elapsed / 1000);
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: SpaceNotesTheme.hairline),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, child) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: const ColoredBox(color: SpaceNotesTheme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_speedLabel,
                  style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      color: SpaceNotesTheme.muted,
                      fontSize: 11)),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      color: SpaceNotesTheme.muted,
                      fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.localPath});

  final String localPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpaceNotesTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: SpaceNotesTheme.hairlineStrong, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => SharePlus.instance.share(
          ShareParams(files: [XFile(localPath)]),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.ios_share, size: 20, color: SpaceNotesTheme.fg),
        ),
      ),
    );
  }
}
