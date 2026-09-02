import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';
import '../utils/pops_when_file_deleted.dart';
import '../widgets/download_progress.dart';
import '../widgets/share_button.dart';

class VideoViewerScreen extends ConsumerStatefulWidget {
  const VideoViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends ConsumerState<VideoViewerScreen>
    with PopsWhenFileDeleted<VideoViewerScreen> {
  bool _loading = false;
  double _progress = 0;
  int _receivedBytes = 0;
  DateTime? _downloadStartedAt;
  String? _error;
  String? _localPath;
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final ready = _controller != null && _controller!.value.isInitialized;
    final fullscreen = isLandscape && ready;

    final content = _error != null
        ? Center(
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)))
        : ready
            ? _VideoPlayerBody(
                controller: _controller!,
                fillScreen: fullscreen,
              )
            : Center(
                child: DownloadProgress(
                  progress: _progress,
                  receivedBytes: _receivedBytes,
                  startedAt: _downloadStartedAt,
                ),
              );

    return ColoredBox(
      color: fullscreen ? Colors.black : SpaceNotesTheme.bg,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            fullscreen ? content : Center(child: content),
            if (fullscreen)
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
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
    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    final state = await store.stateFor(remotePath);

    if (state == DownloadState.complete) {
      await _initPlayer(localPath);
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
      final verified =
          await store.markCompleteIfVerified(remotePath, localPath, expectedSize);
      debugLogger.info(
        'VIDEO_VIEWER',
        verified ? 'Verified and marked complete' : 'Verification FAILED',
        remotePath,
      );
      await _initPlayer(localPath);
    } catch (e, st) {
      debugLogger.error('VIDEO_VIEWER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load video: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      ref.invalidate(downloadStateProvider(remotePath));
    }
  }

  Future<void> _initPlayer(String localPath) async {
    final controller = VideoPlayerController.file(File(localPath));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _localPath = localPath;
      });
      controller.play();
    } catch (e) {
      await controller.dispose();
      debugLogger.error('VIDEO_VIEWER', 'Player init failed: $localPath', e.toString());
      if (mounted) setState(() => _error = 'Could not play video: $e');
    }
  }
}

class _VideoPlayerBody extends StatefulWidget {
  const _VideoPlayerBody({required this.controller, this.fillScreen = false});

  final VideoPlayerController controller;
  final bool fillScreen;

  @override
  State<_VideoPlayerBody> createState() => _VideoPlayerBodyState();
}

class _VideoPlayerBodyState extends State<_VideoPlayerBody> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;
    final aspectRatio = value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio;

    final tapToPlay = GestureDetector(
      onTap: () {
        setState(() {
          value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(controller),
          if (!value.isPlaying)
            const Icon(Icons.play_arrow, size: 56, color: Colors.white70),
        ],
      ),
    );

    if (widget.fillScreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(aspectRatio: aspectRatio, child: tapToPlay),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: SpaceNotesTheme.accent,
                bufferedColor: SpaceNotesTheme.hairlineStrong,
                backgroundColor: SpaceNotesTheme.hairline,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(aspectRatio: aspectRatio, child: tapToPlay),
        const SizedBox(height: 12),
        SizedBox(
          width: 280,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: SpaceNotesTheme.accent,
              bufferedColor: SpaceNotesTheme.hairlineStrong,
              backgroundColor: SpaceNotesTheme.hairline,
            ),
          ),
        ),
      ],
    );
  }

  void _onTick() {
    if (mounted) setState(() {});
  }
}
