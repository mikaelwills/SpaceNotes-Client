import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/audio_playback_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/file_transfer_providers.dart';
import '../services/local_download_store.dart';
import '../services/debug_logger.dart';
import '../theme/spacenotes_theme.dart';
import 'audio_file_picker.dart';
import 'download_progress.dart';
import 'parametric_eq_pad.dart';
import 'primitives/sn_micro_label.dart';
import 'primitives/sn_status_line.dart';
import 'waveform_scrubber.dart';

enum _PlayerMode { transport, eq }

class AudioFilePlayer extends ConsumerStatefulWidget {
  const AudioFilePlayer({
    super.key,
    required this.fileId,
    this.replaceable = false,
    this.onReplace,
  });

  final String fileId;

  /// Shows a replace icon in the status row when true. [onReplace] must be
  /// supplied in that case — called with the newly picked file's id.
  final bool replaceable;
  final ValueChanged<String>? onReplace;

  @override
  ConsumerState<AudioFilePlayer> createState() => _AudioFilePlayerState();
}

class _AudioFilePlayerState extends ConsumerState<AudioFilePlayer> {
  _PlayerMode _mode = _PlayerMode.transport;
  bool _started = false;
  bool _isCurrent = false;
  double _progress = 0;
  int _receivedBytes = 0;
  DateTime? _downloadStartedAt;
  String? _error;
  String? _localPath;
  List<double>? _lastPeaks;
  Duration _lastDuration = Duration.zero;
  List<EqNotch> _lastNotches = const [];
  bool _lastEqBypassed = false;

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileByIdProvider(widget.fileId));
    if (file == null) return const SizedBox.shrink();

    final playback = ref.watch(audioPlaybackProvider);
    final controller = ref.read(audioPlaybackProvider.notifier);
    final isCurrent = playback.fileId == widget.fileId;
    _isCurrent = isCurrent;
    final remotePath = file.path;

    final size = file.size.toInt();
    final title = file.name;

    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isCurrent) {
          _resolveLocalPath(remotePath);
        } else {
          _ensureAvailable(remotePath, size, title);
        }
      });
    }

    if (isCurrent) {
      _lastPeaks = playback.peaks;
      _lastDuration = playback.duration;
      _lastNotches = playback.notches;
      _lastEqBypassed = playback.eqBypassed;
    }

    if (!isCurrent && _localPath != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _ensureAvailable(remotePath, size, title),
          child: Opacity(
            opacity: 0.7,
            child: IgnorePointer(
              child: SizedBox(
                width: double.infinity,
                child: _PlayerBody(
                  fileName: file.name,
                  localPath: null,
                  mode: _mode,
                  onModeChanged: (_) {},
                  isPlaying: false,
                  position: controller.lastPositionFor(widget.fileId),
                  duration: _lastDuration,
                  peaks: _lastPeaks,
                  formatDuration: _formatDuration,
                  onPlayPause: () {},
                  onSeek: (_) {},
                  onSkip: (_) {},
                  notches: _lastNotches,
                  eqBypassed: _lastEqBypassed,
                  onToggleEqBypass: null,
                  onNotchChanged: (_, __) {},
                  onNotchCleared: (_) {},
                  onReplace: null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: _error != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            )
          : isCurrent && _localPath != null
              ? SizedBox(
                  width: double.infinity,
                  child: _PlayerBody(
                    fileName: file.name,
                    localPath: _localPath,
                    mode: _mode,
                    onModeChanged: (mode) => setState(() => _mode = mode),
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
                    onReplace: widget.replaceable ? _pickReplacement : null,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _downloadStartedAt != null
                      ? DownloadProgress(
                          progress: _progress,
                          receivedBytes: _receivedBytes,
                          startedAt: _downloadStartedAt,
                          totalBytes: file.size.toInt(),
                        )
                      : const CircularProgressIndicator(),
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
      debugLogger.error('AUDIO_PLAYER', 'Fetch failed: $remotePath', '$e\n$st');
      if (mounted) setState(() => _error = 'Could not load audio: $e');
    } finally {
      if (mounted) ref.invalidate(downloadStateProvider(remotePath));
    }
  }

  Future<void> _initPlayer(String localPath, String title) async {
    if (!mounted) return;
    try {
      debugLogger.info(
          'AUDIO_PLAYER', 'Loading into native EQ player', localPath);
      await ref.read(audioPlaybackProvider.notifier).load(
            fileId: widget.fileId,
            localPath: localPath,
            title: title,
          );
      debugLogger.info('AUDIO_PLAYER', 'Play command sent', localPath);
      if (mounted) setState(() => _localPath = localPath);
    } catch (e) {
      debugLogger.error(
          'AUDIO_PLAYER', 'Player init failed: $localPath', e.toString());
      if (mounted) setState(() => _error = 'Could not play audio: $e');
    }
  }

  Future<void> _pickReplacement() async {
    final newFileId = await pickAudioFile(context, ref);
    if (newFileId == null || !mounted) return;
    widget.onReplace?.call(newFileId);
  }

  @override
  void dispose() {
    if (!_isCurrent) {
      ref.read(audioPlaybackProvider.notifier).clearLastPosition(widget.fileId);
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.fileName,
    required this.localPath,
    required this.mode,
    required this.onModeChanged,
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
    this.onReplace,
  });

  final String fileName;
  final String? localPath;
  final _PlayerMode mode;
  final ValueChanged<_PlayerMode> onModeChanged;
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
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SnStatusLine(
          divider: false,
          leading:
              SnUiText(fileName, color: SpaceNotesTheme.muted, fontSize: 10),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReplace != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onReplace,
                  child: const Icon(Icons.swap_horiz,
                      size: 14, color: SpaceNotesTheme.muted),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onModeChanged(
                  mode == _PlayerMode.transport
                      ? _PlayerMode.eq
                      : _PlayerMode.transport,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: SpaceNotesTheme.hairline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SnMicroLabel(
                    mode == _PlayerMode.transport ? 'eq' : 'transport',
                    color: SpaceNotesTheme.accent,
                  ),
                ),
              ),
              if (localPath != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => SharePlus.instance.share(
                    ShareParams(files: [XFile(localPath!)]),
                  ),
                  child: const Icon(Icons.ios_share,
                      size: 14, color: SpaceNotesTheme.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      ignoring: mode == _PlayerMode.eq,
                      child: mode == _PlayerMode.eq
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                SpaceNotesTheme.dim,
                                BlendMode.modulate,
                              ),
                              child: WaveformScrubber(
                                peaks: peaks,
                                binSeconds: audioWaveformBinSeconds,
                                position: position,
                                duration: duration,
                                isPlaying: isPlaying,
                                onSeek: onSeek,
                                onTogglePlayPause: onPlayPause,
                              ),
                            )
                          : WaveformScrubber(
                              peaks: peaks,
                              binSeconds: audioWaveformBinSeconds,
                              position: position,
                              duration: duration,
                              isPlaying: isPlaying,
                              onSeek: onSeek,
                              onTogglePlayPause: onPlayPause,
                            ),
                    ),
                    if (mode == _PlayerMode.transport) ...[
                      Positioned(
                        left: 8,
                        child: _WaveformButtonChip(
                          onTap: () => onSkip(-audioSkipStep),
                          child: const Icon(Icons.replay_10,
                              size: 16, color: SpaceNotesTheme.fg),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        child: _WaveformButtonChip(
                          onTap: () => onSkip(audioSkipStep),
                          child: const Icon(Icons.forward_10,
                              size: 16, color: SpaceNotesTheme.fg),
                        ),
                      ),
                    ] else ...[
                      Positioned.fill(
                        child: ParametricEqPad(
                          notches: notches,
                          bypassed: eqBypassed,
                          onNotchChanged: onNotchChanged,
                          onNotchCleared: onNotchCleared,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _WaveformButtonChip(
                          onTap: onToggleEqBypass,
                          child: Icon(
                            eqBypassed
                                ? Icons.power_settings_new
                                : Icons.power_settings_new_outlined,
                            size: 14,
                            color: onToggleEqBypass == null
                                ? SpaceNotesTheme.dim
                                : eqBypassed
                                    ? SpaceNotesTheme.muted
                                    : SpaceNotesTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
      ],
    );
  }
}

class _WaveformButtonChip extends StatelessWidget {
  const _WaveformButtonChip({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: onTap == null
            ? Padding(padding: const EdgeInsets.all(6), child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: const EdgeInsets.all(6), child: child),
              ),
      ),
    );
  }
}
