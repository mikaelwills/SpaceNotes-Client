import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../services/parametric_eq_service.dart';
import '../theme/spacenotes_theme.dart';
import '../utils/pops_when_file_deleted.dart';
import '../widgets/download_progress.dart';
import '../widgets/parametric_eq_pad.dart';
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

  final ParametricEqService _eq = ParametricEqService();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  Timer? _positionPoll;

  bool _eqPadOpen = false;
  EqNotch? _notch;
  bool _eqBypassed = false;

  @override
  void initState() {
    super.initState();
    _eq.onPlaybackStateChanged = (isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
    };
  }

  @override
  void dispose() {
    _positionPoll?.cancel();
    _eq.onPlaybackStateChanged = null;
    _eq.stop();
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
                      ? SizedBox(
                          width: double.infinity,
                          child: _AudioPlayerBody(
                            isPlaying: _isPlaying,
                            position: _position,
                            duration: _duration,
                            formatDuration: _formatDuration,
                            onPlayPause: _togglePlayPause,
                            onSeek: (value) {
                              _eq.seek(Duration(milliseconds: value.round()));
                            },
                            eqPadOpen: _eqPadOpen,
                            onToggleEqPad: () =>
                                setState(() => _eqPadOpen = !_eqPadOpen),
                            notch: _notch,
                            eqBypassed: _eqBypassed,
                            onToggleEqBypass: _notch == null
                                ? null
                                : () {
                                    final bypassing = !_eqBypassed;
                                    setState(() => _eqBypassed = bypassing);
                                    if (bypassing) {
                                      _eq.clearEq();
                                    } else {
                                      _eq.setEq(
                                        frequencyHz: _notch!.frequencyHz,
                                        gainDb: _notch!.gainDb,
                                        bandwidth: _notch!.bandwidth,
                                      );
                                    }
                                  },
                            onNotchChanged: (notch) {
                              setState(() => _notch = notch);
                              if (!_eqBypassed) {
                                _eq.setEq(
                                  frequencyHz: notch.frequencyHz,
                                  gainDb: notch.gainDb,
                                  bandwidth: notch.bandwidth,
                                );
                              }
                            },
                            onNotchCleared: () {
                              setState(() {
                                _notch = null;
                                _eqBypassed = false;
                              });
                              _eq.clearEq();
                            },
                          ),
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
      debugLogger.info('AUDIO_VIEWER', 'Loading into native EQ player', localPath);
      final title = ref.read(fileByIdProvider(widget.fileId))?.name;
      final loaded = await _eq.load(localPath, title: title);
      debugLogger.info('AUDIO_VIEWER', 'Native load result', 'loaded=$loaded');
      if (!loaded) throw Exception('native player failed to load file');
      if (!mounted) return;
      final duration = await _eq.duration();
      debugLogger.info('AUDIO_VIEWER', 'Duration reported', '${duration.inMilliseconds}ms');
      setState(() {
        _localPath = localPath;
        _duration = duration;
      });
      await _eq.play();
      debugLogger.info('AUDIO_VIEWER', 'Play command sent', localPath);
      setState(() => _isPlaying = true);
      _startPositionPoll();
    } catch (e) {
      debugLogger.error('AUDIO_VIEWER', 'Player init failed: $localPath', e.toString());
      if (mounted) setState(() => _error = 'Could not play audio: $e');
    }
  }

  void _startPositionPoll() {
    _positionPoll?.cancel();
    _positionPoll = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!mounted) return;
      final position = await _eq.position();
      if (mounted) setState(() => _position = position);
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _eq.pause();
      setState(() => _isPlaying = false);
    } else {
      await _eq.play();
      setState(() => _isPlaying = true);
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
    required this.eqPadOpen,
    required this.onToggleEqPad,
    required this.notch,
    required this.eqBypassed,
    required this.onToggleEqBypass,
    required this.onNotchChanged,
    required this.onNotchCleared,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final bool eqPadOpen;
  final VoidCallback onToggleEqPad;
  final EqNotch? notch;
  final bool eqBypassed;
  final VoidCallback? onToggleEqBypass;
  final ValueChanged<EqNotch> onNotchChanged;
  final VoidCallback onNotchCleared;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds.toDouble();
    final currentMs = position.inMilliseconds
        .toDouble()
        .clamp(0, totalMs == 0 ? 1 : totalMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eqPadOpen) ...[
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  ParametricEqPad(
                    notch: notch,
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
        ] else ...[
          const Icon(Icons.music_note_outlined, size: 64, color: SpaceNotesTheme.accent),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 48,
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: SpaceNotesTheme.accent,
              ),
              onPressed: onPlayPause,
            ),
            IconButton(
              iconSize: 26,
              icon: Icon(
                Icons.graphic_eq,
                color: eqPadOpen ? SpaceNotesTheme.accent : SpaceNotesTheme.muted,
              ),
              onPressed: onToggleEqPad,
            ),
          ],
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
