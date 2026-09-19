import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_playback_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';
import '../utils/pops_when_file_deleted.dart';
import '../widgets/download_progress.dart';
import '../widgets/parametric_eq_pad.dart';
import '../widgets/share_button.dart';
import '../widgets/waveform_scrubber.dart';

class AudioViewerScreen extends ConsumerStatefulWidget {
  const AudioViewerScreen({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<AudioViewerScreen> createState() => _AudioViewerScreenState();
}

class _AudioViewerScreenState extends ConsumerState<AudioViewerScreen>
    with PopsWhenFileDeleted<AudioViewerScreen> {
  bool _started = false;
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

    final playback = ref.watch(audioPlaybackProvider);
    final controller = ref.read(audioPlaybackProvider.notifier);
    final isCurrent = playback.fileId == widget.fileId;
    final remotePath = file!.path;

    if (!_started) {
      _started = true;
      final size = file.size.toInt();
      final title = file.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isCurrent) {
          _resolveLocalPath(remotePath);
        } else {
          _ensureAvailable(remotePath, size, title);
        }
      });
    }

    return ColoredBox(
      color: SpaceNotesTheme.bg,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13))
                  : isCurrent && playback.peaks != null
                      ? SizedBox(
                          width: double.infinity,
                          child: _AudioPlayerBody(
                            isPlaying: playback.isPlaying,
                            position: playback.position,
                            duration: playback.duration,
                            peaks: playback.peaks,
                            formatDuration: _formatDuration,
                            onPlayPause: controller.togglePlayPause,
                            onSeek: controller.seek,
                            onSkip: controller.skip,
                            notches: playback.notches,
                            eqBypassed: playback.eqBypassed,
                            onToggleEqBypass: playback.notches.isEmpty
                                ? null
                                : controller.toggleEqBypass,
                            onNotchChanged: controller.setNotch,
                            onNotchCleared: controller.clearNotch,
                          ),
                        )
                      : _downloadStartedAt != null
                          ? DownloadProgress(
                              progress: _progress,
                              receivedBytes: _receivedBytes,
                              startedAt: _downloadStartedAt,
                              totalBytes: file.size.toInt(),
                            )
                          : const CircularProgressIndicator(),
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

  Future<void> _resolveLocalPath(String remotePath) async {
    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    if (mounted) setState(() => _localPath = localPath);
  }

  Future<void> _ensureAvailable(
      String remotePath, int expectedSize, String title) async {
    final store = ref.read(localDownloadStoreProvider);
    final localPath = await store.localPathFor(remotePath);
    final state = await store.stateFor(remotePath, expectedSize: expectedSize);

    if (state == DownloadState.complete) {
      await _initPlayer(localPath, title);
      return;
    }

    setState(() {
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
      await _initPlayer(localPath, title);
    } catch (e, st) {
      debugLogger.error('AUDIO_VIEWER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load audio: $e');
    } finally {
      if (mounted) ref.invalidate(downloadStateProvider(remotePath));
    }
  }

  Future<void> _initPlayer(String localPath, String title) async {
    if (!mounted) return;
    try {
      debugLogger.info(
          'AUDIO_VIEWER', 'Loading into native EQ player', localPath);
      await ref.read(audioPlaybackProvider.notifier).load(
            fileId: widget.fileId,
            localPath: localPath,
            title: title,
          );
      debugLogger.info('AUDIO_VIEWER', 'Play command sent', localPath);
      if (mounted) setState(() => _localPath = localPath);
    } catch (e) {
      debugLogger.error(
          'AUDIO_VIEWER', 'Player init failed: $localPath', e.toString());
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
    required this.peaks,
    required this.formatDuration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSkip,
    required this.notches,
    required this.eqBypassed,
    required this.onToggleEqBypass,
    required this.onNotchChanged,
    required this.onNotchCleared,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<double>? peaks;
  final String Function(Duration) formatDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSkip;
  final List<EqNotch> notches;
  final bool eqBypassed;
  final VoidCallback? onToggleEqBypass;
  final void Function(int index, EqNotch notch) onNotchChanged;
  final ValueChanged<int> onNotchCleared;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                ParametricEqPad(
                  notches: notches,
                  bypassed: eqBypassed,
                  onNotchChanged: onNotchChanged,
                  onNotchCleared: onNotchCleared,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    iconSize: 22,
                    icon: Icon(
                      eqBypassed
                          ? Icons.power_settings_new
                          : Icons.power_settings_new_outlined,
                      color: onToggleEqBypass == null
                          ? SpaceNotesTheme.dim
                          : eqBypassed
                              ? SpaceNotesTheme.muted
                              : SpaceNotesTheme.accent,
                    ),
                    onPressed: onToggleEqBypass,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              WaveformScrubber(
                peaks: peaks,
                binSeconds: audioWaveformBinSeconds,
                position: position,
                duration: duration,
                isPlaying: isPlaying,
                onSeek: onSeek,
              ),
              const SizedBox(height: 6),
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
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 30,
              icon: const Icon(Icons.replay_10, color: SpaceNotesTheme.fg),
              onPressed: () => onSkip(-audioSkipStep),
            ),
            IconButton(
              iconSize: 48,
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: SpaceNotesTheme.accent,
              ),
              onPressed: onPlayPause,
            ),
            IconButton(
              iconSize: 30,
              icon: const Icon(Icons.forward_10, color: SpaceNotesTheme.fg),
              onPressed: () => onSkip(audioSkipStep),
            ),
          ],
        ),
      ],
    );
  }
}
