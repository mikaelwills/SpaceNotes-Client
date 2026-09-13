import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/audio_playback_provider.dart';
import '../theme/spacenotes_theme.dart';
import 'adaptive/platform_utils.dart';

const double _miniBarTile = 52;

class AudioMiniBar extends ConsumerWidget {
  const AudioMiniBar({super.key});

  static bool isVisible(BuildContext context, String? fileId) {
    if (fileId == null) return false;
    return GoRouterState.of(context).uri.path != '/notes/note/$fileId';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioPlaybackProvider);
    final fileId = playback.fileId;
    if (!isVisible(context, fileId)) return const SizedBox.shrink();

    final controller = ref.read(audioPlaybackProvider.notifier);
    final isDesktop = PlatformUtils.isDesktopLayout(context);

    final surface = _MiniBarSurface(
      playback: playback,
      isDesktop: isDesktop,
      onTap: () => context.go('/notes/note/$fileId'),
      onPlayPause: controller.togglePlayPause,
      onSkip: controller.skip,
      onDismiss: controller.stop,
    );

    return Dismissible(
      key: ValueKey('audio-mini-bar-$fileId'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => controller.stop(),
      child: isDesktop
          ? surface
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: surface,
            ),
    );
  }
}

class _MiniBarSurface extends StatelessWidget {
  const _MiniBarSurface({
    required this.playback,
    required this.isDesktop,
    required this.onTap,
    required this.onPlayPause,
    required this.onSkip,
    required this.onDismiss,
  });

  final AudioPlaybackState playback;
  final bool isDesktop;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSkip;
  final VoidCallback onDismiss;

  static const BorderRadius _mobileRadius =
      BorderRadius.vertical(top: Radius.circular(SpaceNotesTheme.radiusXs));

  @override
  Widget build(BuildContext context) {
    final decoration = isDesktop
        ? const BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border(
              bottom: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
            ),
          )
        : const BoxDecoration(
            color: SpaceNotesTheme.bgAlt,
            border: Border(
              top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
              left: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
              right: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
            ),
            borderRadius: _mobileRadius,
          );

    return Semantics(
      label: 'now playing ${playback.title}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: decoration,
          child: ClipRRect(
            borderRadius: isDesktop ? BorderRadius.zero : _mobileRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressLine(progress: playback.progress),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            playback.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: SpaceNotesTheme.fontSans,
                              fontSize: 13,
                              color: SpaceNotesTheme.fg,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_format(playback.position)} / ${_format(playback.duration)}',
                            style: const TextStyle(
                              fontFamily: SpaceNotesTheme.fontMono,
                              fontSize: 10,
                              color: SpaceNotesTheme.muted,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SkipButton(
                      icon: Icons.replay_10,
                      tooltip: 'back 10 seconds',
                      onPressed: () => onSkip(-audioSkipStep),
                    ),
                    _TransportButton(
                      isPlaying: playback.isPlaying,
                      onPressed: onPlayPause,
                    ),
                    _SkipButton(
                      icon: Icons.forward_10,
                      tooltip: 'forward 10 seconds',
                      onPressed: () => onSkip(audioSkipStep),
                    ),
                    if (isDesktop)
                      IconButton(
                        iconSize: 16,
                        tooltip: 'stop',
                        icon: const Icon(Icons.close,
                            color: SpaceNotesTheme.muted),
                        onPressed: onDismiss,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: SpaceNotesTheme.hairlineStrong,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1,
          child: const ColoredBox(color: SpaceNotesTheme.accent),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 26,
      padding: EdgeInsets.zero,
      constraints:
          const BoxConstraints.tightFor(width: _miniBarTile, height: 48),
      tooltip: isPlaying ? 'pause' : 'play',
      icon: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: SpaceNotesTheme.accent,
      ),
      onPressed: onPressed,
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints:
          const BoxConstraints.tightFor(width: _miniBarTile, height: 48),
      tooltip: tooltip,
      icon: Icon(icon, color: SpaceNotesTheme.fg),
      onPressed: onPressed,
    );
  }
}
