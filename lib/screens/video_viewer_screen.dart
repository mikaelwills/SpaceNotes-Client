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
import '../widgets/downloading_badge.dart';
import '../widgets/share_button.dart';

class VideoViewerScreen extends ConsumerStatefulWidget {
  const VideoViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends ConsumerState<VideoViewerScreen>
    with PopsWhenFileDeleted<VideoViewerScreen> {
  bool _started = false;
  String? _error;
  String? _localPath;
  double _downloadProgress = 1.0;
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

    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPlayback(remotePath, file.size.toInt());
      });
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final ready = _controller != null && _controller!.value.isInitialized;
    final fullscreen = isLandscape && ready;

    final content = _error != null
        ? _VideoErrorPanel(
            message: _error!,
            path: remotePath,
            onRetry: () => _retryFresh(remotePath, file.size.toInt()),
          )
        : ready
            ? _VideoPlayerBody(
                controller: _controller!,
                fillScreen: fullscreen,
              )
            : const Center(child: CircularProgressIndicator());

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
            if (!fullscreen && _downloadProgress < 1.0)
              Positioned(
                left: 16,
                bottom: 16,
                child: DownloadingBadge(progress: _downloadProgress),
              ),
            if (!fullscreen && _localPath != null)
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

  /// Plays immediately over HTTP (the server supports Range requests), and
  /// separately downloads the file to disk in the background so the next
  /// open of this file is instant and offline-capable. The two are
  /// independent: closing the screen mid-stream does not need to preserve
  /// anything, since the background download is the thing that persists.
  Future<void> _startPlayback(String remotePath, int expectedSize) async {
    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    final state = await store.stateFor(remotePath, expectedSize: expectedSize);

    if (state == DownloadState.complete) {
      await _initPlayer(networkUrl: null, localPath: localPath);
      return;
    }

    final service = ref.read(fileTransferServiceProvider);
    await _initPlayer(
      networkUrl: service.streamUrl(remotePath),
      localPath: localPath,
    );
    setState(() => _downloadProgress = 0);
    ref.read(backgroundDownloadProvider).run(
          remotePath: remotePath,
          expectedSize: expectedSize,
          mounted: () => mounted,
          onProgress: (progress) => setState(() {
            _downloadProgress = progress;
            if (progress >= 1.0) _localPath = localPath;
          }),
        );
  }

  Future<void> _initPlayer({required String? networkUrl, required String localPath}) async {
    final controller = networkUrl != null
        ? VideoPlayerController.networkUrl(Uri.parse(networkUrl))
        : VideoPlayerController.file(File(localPath));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final value = controller.value;
      debugLogger.info(
        'VIDEO_VIEWER',
        'Player initialised',
        'size=${value.size.width.toInt()}x${value.size.height.toInt()} '
            'duration=${value.duration.inMilliseconds}ms streaming=${networkUrl != null}',
      );
      if (value.size.width == 0 || value.size.height == 0) {
        await controller.dispose();
        _fail(
          'The file opened but contains no video track this device can decode '
          '(reported size 0×0, duration ${_formatDuration(value.duration)}).\n\n'
          'Usually the codec: iOS plays H.264 and HEVC, not VP9 or AV1. '
          'Check with ffprobe on the NAS and re-encode to H.264.',
        );
        return;
      }
      controller.addListener(_onControllerChanged);
      setState(() {
        _controller = controller;
        _localPath = networkUrl == null ? localPath : null;
      });
      controller.play();
    } catch (e) {
      await controller.dispose();
      _fail('Player failed to initialise.\n\n$e');
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError || _error != null) {
      return;
    }
    final description = controller.value.errorDescription ?? 'unknown error';
    controller.removeListener(_onControllerChanged);
    _fail('Playback error after start.\n\n$description');
  }

  Future<void> _retryFresh(String remotePath, int expectedSize) async {
    debugLogger.info('VIDEO_VIEWER', 'Deleting local copy and retrying', remotePath);
    await ref.read(localDownloadStoreProvider).remove(remotePath);
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
    if (!mounted) return;
    setState(() {
      _error = null;
      _localPath = null;
    });
    await _startPlayback(remotePath, expectedSize);
  }

  void _fail(String message) {
    debugLogger.error('VIDEO_VIEWER', 'Playback failed', message);
    if (mounted) setState(() => _error = message);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _VideoErrorPanel extends StatelessWidget {
  const _VideoErrorPanel({
    required this.message,
    required this.path,
    required this.onRetry,
  });

  final String message;
  final String path;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 22, color: SpaceNotesTheme.offline),
              SizedBox(width: 10),
              Text(
                "Couldn't play this video",
                style: TextStyle(
                  color: SpaceNotesTheme.fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            message,
            style: const TextStyle(
              color: SpaceNotesTheme.fg,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            path,
            style: const TextStyle(
              color: SpaceNotesTheme.muted,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Delete download and retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SpaceNotesTheme.accent,
              side: const BorderSide(color: SpaceNotesTheme.hairlineStrong),
            ),
          ),
        ],
      ),
    );
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

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          tapToPlay,
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
      ),
    );
  }

  void _onTick() {
    if (mounted) setState(() {});
  }
}
