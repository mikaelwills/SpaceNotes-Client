import 'dart:async';
import 'package:flutter/material.dart';
import '../services/video_stats.dart';
import '../theme/spacenotes_theme.dart';

class VideoStatsOverlay extends StatefulWidget {
  final VideoStats? videoStats;

  const VideoStatsOverlay({super.key, required this.videoStats});

  @override
  State<VideoStatsOverlay> createState() => _VideoStatsOverlayState();
}

class _VideoStatsOverlayState extends State<VideoStatsOverlay> {
  bool _expanded = false;
  Timer? _timer;
  VideoStatsSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || widget.videoStats == null) return;
      setState(() => _snap = widget.videoStats!.snapshot());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoStats == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildCollapsed() {
    final s = _snap;
    final label = s != null
        ? 'TX ${s.sendFps.toStringAsFixed(0)} / RX ${s.receiveFps.toStringAsFixed(0)}'
        : 'STATS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.background.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 10,
          color: SpaceNotesTheme.primary,
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final s = _snap;
    if (s == null) return _buildCollapsed();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.primary.withValues(alpha: 0.3)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 10,
          color: SpaceNotesTheme.text,
          height: 1.5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('TX ${s.sendFps.toStringAsFixed(1)} fps'),
                _row('Capture', '${s.avgCaptureMs.toStringAsFixed(0)}ms', s.avgCaptureMs > 30),
                if (s.avgYuvMs > 0) _row('  YUV', '${s.avgYuvMs.toStringAsFixed(0)}ms', s.avgYuvMs > 20),
                if (s.avgEncodeMs > 0) _row('  JPEG', '${s.avgEncodeMs.toStringAsFixed(0)}ms', s.avgEncodeMs > 20),
                _row('Size', '${s.avgSendKB.toStringAsFixed(0)} KB', false),
                _dim('Sent ${s.totalSent}'),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('RX ${s.receiveFps.toStringAsFixed(1)} fps'),
                _row('Display', '${s.avgDisplayLatencyMs.toStringAsFixed(0)}ms', s.avgDisplayLatencyMs > 30),
                _row('Size', '${s.avgReceiveKB.toStringAsFixed(0)} KB', false),
                _row('Drops', '${s.droppedFrames}', s.droppedFrames > 0),
                if (s.audioLatencyMs != null && s.audioLatencyMs! > 0)
                  _row('Audio', '${s.audioLatencyMs!.toStringAsFixed(0)}ms', s.audioLatencyMs! > 200),
                _dim('Recv ${s.totalReceived}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(color: SpaceNotesTheme.primary, fontWeight: FontWeight.w600));
  }

  Widget _row(String label, String value, bool warn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(color: SpaceNotesTheme.textSecondary)),
        ),
        Text(value, style: TextStyle(color: warn ? SpaceNotesTheme.warning : SpaceNotesTheme.text)),
      ],
    );
  }

  Widget _dim(String text) {
    return Text(text, style: const TextStyle(color: SpaceNotesTheme.textSecondary, fontSize: 9));
  }
}
