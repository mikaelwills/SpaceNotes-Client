import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/call_session.dart';
import '../generated/call_state.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../services/call_service.dart';
import '../services/debug_logger.dart';
import '../services/h264_decoder_service.dart';
import '../services/web_h264_decoder_export.dart';
import '../services/video_capture_mobile.dart';
import '../widgets/web_h264_view.dart';
import '../theme/spacenotes_theme.dart';
import '../services/video_stats.dart';
import '../widgets/video_stats_overlay.dart';

class CallScreen extends ConsumerStatefulWidget {
  final Int64 sessionId;

  const CallScreen({super.key, required this.sessionId});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _captureStarted = false;
  bool _popping = false;
  bool _muted = false;

  CallService? _callService;

  @override
  void initState() {
    super.initState();
    _callService = ref.read(callServiceProvider);
  }

  @override
  void dispose() {
    debugLogger.info('CALL_SCREEN', 'dispose() called, stopping capture');
    _callService?.stopCapture();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (_captureStarted) return;
    _captureStarted = true;

    final callService = ref.read(callServiceProvider);
    final repo = ref.read(notesRepositoryProvider);
    callService.setClient(repo.client);
    await callService.startCapture(widget.sessionId, fps: 25, width: 2560, height: 1440);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeCallSessionProvider);

    return Scaffold(
      backgroundColor: SpaceNotesTheme.background,
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: SpaceNotesTheme.primary)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: SpaceNotesTheme.error)),
        ),
        data: (session) {
          if (session == null || session.state is CallStateEnded) {
            if (!_popping) {
              _popping = true;
              debugLogger.info('CALL_SCREEN', 'Session ended/null, popping');
              _callService?.stopCapture();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  GoRouter.of(context).go('/notes');
                }
              });
            }
            return const Center(
              child: Text('Call ended', style: TextStyle(color: SpaceNotesTheme.textSecondary)),
            );
          }

        if (session.state is CallStateActive && !_captureStarted) {
          _startCapture();
        }

        final remoteFrame = ref.watch(remoteVideoFrameProvider);

        final callService = ref.read(callServiceProvider);

        if (session.state is CallStateActive) {
          ref.listen(remoteAudioFrameProvider, (prev, next) {
            final audioData = next.valueOrNull;
            if (audioData != null && callService.audioService != null) {
              callService.audioService!.feedRemoteAudio(audioData);
              callService.videoStats?.audioLatencyMs = callService.audioService!.audioLatencyMs.average;
            }
          });
        }

        return Stack(
          children: [
            _RemoteVideo(remoteFrame: remoteFrame, videoStats: callService.videoStats),
            if (session.state is CallStateRinging)
              _RingingOverlay(session: session),
            if (session.state is CallStateActive)
              _LocalPreview(callService: callService),
            if (session.state is CallStateActive)
              _CallControls(
                onEnd: () => _endCall(session),
                onFlipCamera: () => _flipCamera(),
                isMuted: _muted,
                onToggleMute: () => _toggleMute(),
              ),
            if (session.state is CallStateActive)
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(child: VideoStatsOverlay(videoStats: callService.videoStats)),
              ),
          ],
        );
      },
      ),
    );
  }

  Future<void> _flipCamera() async {
    final capture = _callService?.captureService;
    if (capture == null) return;
    try {
      await (capture as dynamic).switchCamera();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _toggleMute() {
    _callService?.audioService?.toggleMute();
    setState(() => _muted = _callService?.audioService?.isMuted ?? false);
  }

  void _endCall(CallSession session) {
    _callService?.setClient(ref.read(notesRepositoryProvider).client);
    _callService?.endCall(session.sessionId);
  }
}

class _RemoteVideo extends StatefulWidget {
  final AsyncValue<ReceivedVideoFrame?> remoteFrame;
  final VideoStats? videoStats;

  const _RemoteVideo({required this.remoteFrame, this.videoStats});

  @override
  State<_RemoteVideo> createState() => _RemoteVideoState();
}

class _RemoteVideoState extends State<_RemoteVideo> {
  ui.Image? _decodedImage;
  Uint8List? _lastBytes;
  bool _decoding = false;
  H264DecoderService? _h264NativeDecoder;
  WebH264Decoder? _h264WebDecoder;
  bool _usingH264 = false;
  bool _decoderStarting = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _h264NativeDecoder = H264DecoderService();
      _h264NativeDecoder!.start().then((_) {
        if (mounted) setState(() => _usingH264 = true);
      });
    }
  }

  @override
  void didUpdateWidget(_RemoteVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final frame = widget.remoteFrame.valueOrNull;
    if (frame == null || frame.data == _lastBytes) return;
    _lastBytes = frame.data;

    if (frame.codec == 0) {
      if (!_decoding) _decodeJpeg(frame.data);
    } else if (frame.codec == 1) {
      _feedH264Frame(frame);
    }
  }

  void _feedH264Frame(ReceivedVideoFrame frame) {
    if (kIsWeb) {
      _h264WebDecoder ??= WebH264Decoder();
      if (!_h264WebDecoder!.isStarted) {
        _h264WebDecoder!.start();
        if (mounted) setState(() => _usingH264 = true);
      }
      _h264WebDecoder!.feedFrame(frame.data, frame.seq, frame.isKeyframe);
    } else {
      if (_h264NativeDecoder != null && _h264NativeDecoder!.isStarted) {
        _h264NativeDecoder!.feedFrame(frame.data, frame.seq, frame.isKeyframe);
      }
    }
    widget.videoStats?.recordDisplay();
  }

  void _decodeJpeg(Uint8List bytes) {
    _decoding = true;
    ui.decodeImageFromList(bytes, (ui.Image image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _decodedImage;
      setState(() {
        _decodedImage = image;
        _decoding = false;
      });
      widget.videoStats?.recordDisplay();
      old?.dispose();
    });
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    _h264NativeDecoder?.stop();
    _h264WebDecoder?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.remoteFrame.when(
      loading: () => Container(
        color: SpaceNotesTheme.background,
        child: const Center(
          child: Text('Waiting for video...', style: TextStyle(color: SpaceNotesTheme.textSecondary)),
        ),
      ),
      error: (_, __) => Container(color: SpaceNotesTheme.background),
      data: (frame) {
        if (frame == null && _decodedImage == null && !_usingH264) {
          return Container(
            color: SpaceNotesTheme.background,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: SpaceNotesTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('No video yet', style: TextStyle(color: SpaceNotesTheme.textSecondary)),
                ],
              ),
            ),
          );
        }
        if (_usingH264) {
          if (kIsWeb) {
            return const SizedBox.expand(child: WebH264View());
          }
          if (_h264NativeDecoder != null && _h264NativeDecoder!.textureId >= 0) {
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1440,
                  height: 2560,
                  child: Texture(textureId: _h264NativeDecoder!.textureId),
                ),
              ),
            );
          }
        }
        if (_decodedImage != null) {
          return SizedBox.expand(
            child: RawImage(
              image: _decodedImage,
              fit: BoxFit.cover,
            ),
          );
        }
        return Container(color: SpaceNotesTheme.background);
      },
    );
  }
}

class _RingingOverlay extends ConsumerWidget {
  final CallSession session;

  const _RingingOverlay({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myIdentity = ref.read(myIdentityProvider);
    final isCaller = session.caller == myIdentity;

    return Container(
      color: SpaceNotesTheme.background.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, size: 80, color: SpaceNotesTheme.primary),
            const SizedBox(height: 24),
            Text(
              isCaller ? 'Calling...' : 'Incoming call',
              style: const TextStyle(fontSize: 24, color: SpaceNotesTheme.text),
            ),
            const SizedBox(height: 8),
            Text(
              isCaller
                  ? session.callee.toHexString.substring(0, 16)
                  : session.caller.toHexString.substring(0, 16),
              style: const TextStyle(fontSize: 14, color: SpaceNotesTheme.textSecondary),
            ),
            const SizedBox(height: 48),
            if (!isCaller) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleButton(
                    icon: Icons.call,
                    color: Colors.green,
                    onTap: () {
                      final callService = ref.read(callServiceProvider);
                      final repo = ref.read(notesRepositoryProvider);
                      callService.setClient(repo.client);
                      callService.acceptCall(session.sessionId);
                    },
                  ),
                  const SizedBox(width: 48),
                  _CircleButton(
                    icon: Icons.call_end,
                    color: SpaceNotesTheme.error,
                    onTap: () {
                      final callService = ref.read(callServiceProvider);
                      final repo = ref.read(notesRepositoryProvider);
                      callService.setClient(repo.client);
                      callService.endCall(session.sessionId);
                    },
                  ),
                ],
              ),
            ] else ...[
              _CircleButton(
                icon: Icons.call_end,
                color: SpaceNotesTheme.error,
                onTap: () {
                  final callService = ref.read(callServiceProvider);
                  final repo = ref.read(notesRepositoryProvider);
                  callService.setClient(repo.client);
                  callService.endCall(session.sessionId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalPreview extends StatelessWidget {
  final dynamic callService;

  const _LocalPreview({required this.callService});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Positioned(
        top: 16,
        right: 16,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('You', style: TextStyle(color: SpaceNotesTheme.textSecondary, fontSize: 12)),
          ),
        ),
      );
    }

    final capture = callService.captureService;
    if (capture == null) return const SizedBox.shrink();

    int textureId = -1;
    try {
      textureId = (capture as dynamic).previewTextureId as int;
    } catch (_) {}

    if (textureId >= 0) {
      return Positioned(
        top: 16,
        right: 16,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1080,
              height: 1920,
              child: Texture(textureId: textureId),
            ),
          ),
        ),
      );
    }

    CameraController? controller;
    if (capture is MobileVideoCaptureService) {
      controller = capture.cameraController;
    }
    if (controller == null || !controller.value.isInitialized) {
      return Positioned(
        top: 16,
        right: 16,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: SpaceNotesTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.videocam_off, color: SpaceNotesTheme.textSecondary),
          ),
        ),
      );
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  final VoidCallback onEnd;
  final VoidCallback? onFlipCamera;
  final bool isMuted;
  final VoidCallback? onToggleMute;

  const _CallControls({required this.onEnd, this.onFlipCamera, this.isMuted = false, this.onToggleMute});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!kIsWeb && onFlipCamera != null)
              _CircleButton(icon: Icons.flip_camera_ios, color: SpaceNotesTheme.inputSurface, size: 52, onTap: onFlipCamera!)
            else
              const SizedBox(width: 52),
            if (onToggleMute != null)
              _CircleButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                color: isMuted ? SpaceNotesTheme.warning : SpaceNotesTheme.inputSurface,
                size: 52,
                onTap: onToggleMute!,
              )
            else
              const SizedBox(width: 52),
            _CircleButton(icon: Icons.call_end, color: SpaceNotesTheme.error, size: 64, onTap: onEnd),
            const SizedBox(width: 52),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}
