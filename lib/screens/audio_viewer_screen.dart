import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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

class AudioViewerScreen extends ConsumerStatefulWidget {
  const AudioViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<AudioViewerScreen> createState() => _AudioViewerScreenState();
}

class _AudioViewerScreenState extends ConsumerState<AudioViewerScreen>
    with PopsWhenFileDeleted<AudioViewerScreen> {
  bool _loading = false;
  double _progress = 0;
  int _receivedBytes = 0;
  DateTime? _downloadStartedAt;
  String? _error;
  String? _localPath;

  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
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

    return ColoredBox(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))
                  : _localPath != null
                      ? _AudioPlayerBody(
                          isPlaying: _isPlaying,
                          position: _position,
                          duration: _duration,
                          formatDuration: _formatDuration,
                          onPlayPause: () {
                            _isPlaying ? _player.pause() : _player.resume();
                          },
                          onSeek: (value) {
                            _player.seek(Duration(milliseconds: value.round()));
                          },
                        )
                      : DownloadProgress(
                          progress: _progress,
                          receivedBytes: _receivedBytes,
                          startedAt: _downloadStartedAt,
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
        'AUDIO_VIEWER',
        verified ? 'Verified and marked complete' : 'Verification FAILED',
        remotePath,
      );
      await _initPlayer(localPath);
    } catch (e, st) {
      debugLogger.error('AUDIO_VIEWER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load audio: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      ref.invalidate(downloadStateProvider(remotePath));
    }
  }

  Future<void> _initPlayer(String localPath) async {
    try {
      await _player.setSource(DeviceFileSource(localPath));
      if (!mounted) return;
      setState(() => _localPath = localPath);
      await _player.resume();
    } catch (e) {
      debugLogger.error('AUDIO_VIEWER', 'Player init failed: $localPath', e.toString());
      if (mounted) setState(() => _error = 'Could not play audio: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _AudioPlayerBody extends StatelessWidget {
  const _AudioPlayerBody({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.formatDuration,
    required this.onPlayPause,
    required this.onSeek,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds.toDouble();
    final currentMs = position.inMilliseconds
        .toDouble()
        .clamp(0, totalMs == 0 ? 1 : totalMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.music_note_outlined, size: 64, color: SpaceNotesTheme.accent),
        const SizedBox(height: 24),
        IconButton(
          iconSize: 48,
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: SpaceNotesTheme.accent,
          ),
          onPressed: onPlayPause,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 280,
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: SpaceNotesTheme.accent,
                  inactiveTrackColor: SpaceNotesTheme.hairline,
                  thumbColor: SpaceNotesTheme.accent,
                  overlayColor: SpaceNotesTheme.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  min: 0,
                  max: totalMs == 0 ? 1 : totalMs,
                  value: currentMs.toDouble(),
                  onChanged: totalMs == 0 ? null : onSeek,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(position),
                        style: const TextStyle(
                            color: SpaceNotesTheme.muted, fontSize: 11)),
                    Text(formatDuration(duration),
                        style: const TextStyle(
                            color: SpaceNotesTheme.muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
