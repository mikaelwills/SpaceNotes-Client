import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import '../generated/call_session.dart';
import '../generated/call_state.dart';
import '../providers/call_providers.dart';
import '../providers/notes_providers.dart';
import '../services/debug_logger.dart';
import '../services/video_capture_mobile.dart';
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

  @override
  void dispose() {
    debugLogger.info('CALL_SCREEN', 'dispose() called, stopping capture');
    ref.read(callServiceProvider).stopCapture();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (_captureStarted) return;
    _captureStarted = true;

    final callService = ref.read(callServiceProvider);
    final repo = ref.read(notesRepositoryProvider);
    callService.setClient(repo.client);
    await callService.startCapture(widget.sessionId, fps: 30, width: 1920, height: 1080);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeCallSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: SpaceNotesTheme.error)),
      ),
      data: (session) {
        if (session == null || session.state is CallStateEnded) {
          if (!_popping) {
            _popping = true;
            debugLogger.info('CALL_SCREEN', 'Session ended/null, popping');
            ref.read(callServiceProvider).stopCapture();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop();
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

        return Stack(
          children: [
            _RemoteVideo(remoteFrame: remoteFrame, videoStats: callService.videoStats),
            if (session.state is CallStateRinging)
              _RingingOverlay(session: session),
            if (session.state is CallStateActive)
              _LocalPreview(callService: callService),
            if (session.state is CallStateActive)
              _CallControls(onEnd: () => _endCall(session)),
            if (session.state is CallStateActive)
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(child: VideoStatsOverlay(videoStats: callService.videoStats)),
              ),
          ],
        );
      },
    );
  }

  void _endCall(CallSession session) {
    final callService = ref.read(callServiceProvider);
    final repo = ref.read(notesRepositoryProvider);
    callService.setClient(repo.client);
    callService.endCall(session.sessionId);
  }
}

class _RemoteVideo extends StatelessWidget {
  final AsyncValue<Uint8List?> remoteFrame;
  final VideoStats? videoStats;

  const _RemoteVideo({required this.remoteFrame, this.videoStats});

  @override
  Widget build(BuildContext context) {
    return remoteFrame.when(
      loading: () => Container(
        color: SpaceNotesTheme.background,
        child: const Center(
          child: Text('Waiting for video...', style: TextStyle(color: SpaceNotesTheme.textSecondary)),
        ),
      ),
      error: (_, __) => Container(color: SpaceNotesTheme.background),
      data: (frameData) {
        if (frameData == null) {
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
        videoStats?.recordDisplay();
        return SizedBox.expand(
          child: Image.memory(
            frameData,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
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
    if (capture == null || capture is! MobileVideoCaptureService) {
      return const SizedBox.shrink();
    }

    final controller = capture.cameraController;
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

  const _CallControls({required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(icon: Icons.call_end, color: SpaceNotesTheme.error, size: 64, onTap: onEnd),
        ],
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
