import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/spacenotes_theme.dart';

class WaveformScrubber extends StatefulWidget {
  const WaveformScrubber({
    super.key,
    required this.peaks,
    required this.binSeconds,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onSeek,
    this.height = 96,
    this.pixelsPerSecond = 12,
    this.playheadFraction = 0.2,
  });

  final List<double>? peaks;
  final double binSeconds;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;
  final double height;
  final double pixelsPerSecond;
  final double playheadFraction;

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late Duration _anchorPosition;
  late DateTime _anchorTime;
  Duration? _scrubPosition;

  @override
  void initState() {
    super.initState();
    _anchor(widget.position);
    _ticker = createTicker((_) => setState(() {}));
    _syncTicker();
  }

  @override
  void didUpdateWidget(WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position ||
        widget.isPlaying != oldWidget.isPlaying) {
      _anchor(widget.position);
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _anchor(Duration position) {
    _anchorPosition = position;
    _anchorTime = DateTime.now();
  }

  void _syncTicker() {
    final shouldTick = widget.isPlaying && _scrubPosition == null;
    if (shouldTick && !_ticker.isActive) _ticker.start();
    if (!shouldTick && _ticker.isActive) _ticker.stop();
  }

  Duration get _displayedPosition {
    final scrubbing = _scrubPosition;
    if (scrubbing != null) return scrubbing;
    if (!widget.isPlaying) return _anchorPosition;
    final elapsed = DateTime.now().difference(_anchorTime);
    return _clamp(_anchorPosition + elapsed);
  }

  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (value > widget.duration) return widget.duration;
    return value;
  }

  Duration _secondsToDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  void _handleDragStart(DragStartDetails details) {
    setState(() => _scrubPosition = _displayedPosition);
    _syncTicker();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final current = _scrubPosition;
    if (current == null) return;
    final deltaSeconds = -details.delta.dx / widget.pixelsPerSecond;
    setState(() {
      _scrubPosition = _clamp(current + _secondsToDuration(deltaSeconds));
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final target = _scrubPosition;
    if (target == null) return;
    widget.onSeek(target);
    setState(() {
      _anchor(target);
      _scrubPosition = null;
    });
    _syncTicker();
  }

  void _handleTapUp(TapUpDetails details, double width) {
    final playheadX = width * widget.playheadFraction;
    final offsetSeconds =
        (details.localPosition.dx - playheadX) / widget.pixelsPerSecond;
    final target =
        _clamp(_displayedPosition + _secondsToDuration(offsetSeconds));
    widget.onSeek(target);
    setState(() => _anchor(target));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onTapUp: (details) => _handleTapUp(details, width),
          child: SizedBox(
            height: widget.height,
            width: width,
            child: CustomPaint(
              painter: _WaveformPainter(
                peaks: widget.peaks,
                binSeconds: widget.binSeconds,
                position: _displayedPosition,
                duration: widget.duration,
                pixelsPerSecond: widget.pixelsPerSecond,
                playheadFraction: widget.playheadFraction,
                scrubbing: _scrubPosition != null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.binSeconds,
    required this.position,
    required this.duration,
    required this.pixelsPerSecond,
    required this.playheadFraction,
    required this.scrubbing,
  });

  final List<double>? peaks;
  final double binSeconds;
  final Duration position;
  final Duration duration;
  final double pixelsPerSecond;
  final double playheadFraction;
  final bool scrubbing;

  static const double barWidth = 2;
  static const double barPitch = 3;
  static const double minBarHeight = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final playheadX = size.width * playheadFraction;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.9;
    final positionSeconds = position.inMilliseconds / 1000;
    final durationSeconds = duration.inMilliseconds / 1000;

    final playedPaint = Paint()
      ..color = SpaceNotesTheme.accent
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final upcomingPaint = Paint()
      ..color = SpaceNotesTheme.muted.withValues(alpha: 0.55)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final bins = peaks;
    final firstBar = (playheadX % barPitch);
    for (var x = firstBar; x <= size.width; x += barPitch) {
      final seconds = positionSeconds + (x - playheadX) / pixelsPerSecond;
      if (seconds < 0 || seconds >= durationSeconds) continue;
      var level = 0.0;
      if (bins != null && bins.isNotEmpty) {
        final index = (seconds / binSeconds).floor().clamp(0, bins.length - 1);
        level = bins[index];
      }
      final half = (minBarHeight + level * (maxBarHeight - minBarHeight)) / 2;
      final paint = x < playheadX ? playedPaint : upcomingPaint;
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        paint,
      );
    }

    final playheadColor =
        scrubbing ? SpaceNotesTheme.accent2 : SpaceNotesTheme.accent;
    final glowPaint = Paint()
      ..color = playheadColor.withValues(alpha: 0.45)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      glowPaint,
    );
    final linePaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(playheadX, 2),
      Offset(playheadX, size.height - 2),
      linePaint,
    );
    canvas.drawCircle(Offset(playheadX, 4), 3.5, Paint()..color = playheadColor);
    canvas.drawCircle(
      Offset(playheadX, size.height - 4),
      3.5,
      Paint()..color = playheadColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.position != position ||
      oldDelegate.duration != duration ||
      oldDelegate.scrubbing != scrubbing;
}
