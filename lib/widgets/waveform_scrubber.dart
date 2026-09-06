import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/debug_logger.dart';
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
    this.height = 180,
    this.pixelsPerSecond = 24,
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

class _WaveformScrubberState extends State<WaveformScrubber> {
  static const Duration _reanchorTolerance = Duration(milliseconds: 250);

  late final Ticker _ticker;
  late final ValueNotifier<Duration> _displayed;
  late Duration _anchorPosition;
  Duration _anchorElapsed = Duration.zero;
  Duration _lastTickElapsed = Duration.zero;
  int _tickCount = 0;
  Duration? _scrubPosition;

  @override
  void initState() {
    super.initState();
    _anchor(widget.position);
    _displayed = ValueNotifier(widget.position);
    _ticker = Ticker(_onTick, debugLabel: 'WaveformScrubber');
    _syncTicker();
  }

  @override
  void didUpdateWidget(WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _anchor(widget.position);
    } else if (widget.position != oldWidget.position) {
      final drift = (widget.position - _displayed.value).abs();
      if (!widget.isPlaying || drift > _reanchorTolerance) {
        _anchor(widget.position);
      }
    }
    if (_scrubPosition == null) _displayed.value = _extrapolated();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _displayed.dispose();
    super.dispose();
  }

  void _anchor(Duration position) {
    _anchorPosition = position;
    _anchorElapsed = _lastTickElapsed;
  }

  void _onTick(Duration elapsed) {
    _lastTickElapsed = elapsed;
    _displayed.value = _extrapolated();
    _tickCount++;
  }

  void _syncTicker() {
    final shouldTick = widget.isPlaying && _scrubPosition == null;
    if (shouldTick && !_ticker.isActive) {
      _lastTickElapsed = Duration.zero;
      _anchorElapsed = Duration.zero;
      _ticker.start();
      debugLogger.info('WAVE', 'ticker started',
          'muted=${_ticker.muted} anchor=${_anchorPosition.inMilliseconds}ms');
    }
    if (!shouldTick && _ticker.isActive) {
      _ticker.stop();
      debugLogger.info('WAVE', 'ticker stopped', 'ticks=$_tickCount');
    }
  }

  Duration _extrapolated() {
    if (!widget.isPlaying) return _anchorPosition;
    return _clamp(_anchorPosition + (_lastTickElapsed - _anchorElapsed));
  }

  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (value > widget.duration) return widget.duration;
    return value;
  }

  Duration _secondsToDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  void _handleDragStart(DragStartDetails details) {
    setState(() => _scrubPosition = _displayed.value);
    _syncTicker();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final current = _scrubPosition;
    if (current == null) return;
    final deltaSeconds = -details.delta.dx / widget.pixelsPerSecond;
    final next = _clamp(current + _secondsToDuration(deltaSeconds));
    _scrubPosition = next;
    _displayed.value = next;
  }

  void _handleDragEnd(DragEndDetails details) {
    final target = _scrubPosition;
    if (target == null) return;
    widget.onSeek(target);
    _anchor(target);
    setState(() => _scrubPosition = null);
    _syncTicker();
  }

  void _handleTapUp(TapUpDetails details, double width) {
    final playheadX = width * widget.playheadFraction;
    final offsetSeconds =
        (details.localPosition.dx - playheadX) / widget.pixelsPerSecond;
    final target =
        _clamp(_displayed.value + _secondsToDuration(offsetSeconds));
    widget.onSeek(target);
    _anchor(target);
    _displayed.value = target;
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
          child: RepaintBoundary(
            child: SizedBox(
              height: widget.height,
              width: width,
              child: CustomPaint(
                isComplex: true,
                willChange: true,
                painter: _WaveformPainter(
                  peaks: widget.peaks,
                  binSeconds: widget.binSeconds,
                  position: _displayed,
                  duration: widget.duration,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  playheadFraction: widget.playheadFraction,
                  scrubbing: _scrubPosition != null,
                ),
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
  }) : super(repaint: position);

  final List<double>? peaks;
  final double binSeconds;
  final ValueListenable<Duration> position;
  final Duration duration;
  final double pixelsPerSecond;
  final double playheadFraction;
  final bool scrubbing;

  static const double barWidth = 2;
  static const double minBarHeight = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final playheadX = size.width * playheadFraction;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.9;
    final positionSeconds = position.value.inMilliseconds / 1000;
    final durationSeconds = duration.inMilliseconds / 1000;

    final visibleSeconds = size.width / pixelsPerSecond;
    final leftSeconds = positionSeconds - playheadX / pixelsPerSecond;
    final firstBin = (leftSeconds / binSeconds).floor() - 1;
    final lastBin = ((leftSeconds + visibleSeconds) / binSeconds).ceil() + 1;
    final barCount = lastBin - firstBin + 1;
    final played = Float32List(barCount * 4);
    final upcoming = Float32List(barCount * 4);
    var playedCount = 0;
    var upcomingCount = 0;

    final bins = peaks;
    for (var bin = firstBin; bin <= lastBin; bin++) {
      final seconds = (bin + 0.5) * binSeconds;
      if (seconds < 0 || seconds >= durationSeconds) continue;
      final x = playheadX + (seconds - positionSeconds) * pixelsPerSecond;
      if (x < -barWidth || x > size.width + barWidth) continue;
      var level = 0.0;
      if (bins != null && bins.isNotEmpty) {
        level = bins[bin.clamp(0, bins.length - 1)];
      }
      final half = (minBarHeight + level * (maxBarHeight - minBarHeight)) / 2;
      if (x < playheadX) {
        final i = playedCount * 4;
        played[i] = x;
        played[i + 1] = centerY - half;
        played[i + 2] = x;
        played[i + 3] = centerY + half;
        playedCount++;
      } else {
        final i = upcomingCount * 4;
        upcoming[i] = x;
        upcoming[i + 1] = centerY - half;
        upcoming[i + 2] = x;
        upcoming[i + 3] = centerY + half;
        upcomingCount++;
      }
    }

    final barPaint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    if (playedCount > 0) {
      barPaint.color = SpaceNotesTheme.accent;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(played, 0, playedCount * 4),
        barPaint,
      );
    }
    if (upcomingCount > 0) {
      barPaint.color = SpaceNotesTheme.muted.withValues(alpha: 0.55);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(upcoming, 0, upcomingCount * 4),
        barPaint,
      );
    }

    final playheadColor =
        scrubbing ? SpaceNotesTheme.accent2 : SpaceNotesTheme.accent;
    final haloPaint = Paint()
      ..color = playheadColor.withValues(alpha: 0.18)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(playheadX, 2),
      Offset(playheadX, size.height - 2),
      haloPaint,
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
    final dotPaint = Paint()..color = playheadColor;
    canvas.drawCircle(Offset(playheadX, 4), 3.5, dotPaint);
    canvas.drawCircle(Offset(playheadX, size.height - 4), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.position != position ||
      oldDelegate.duration != duration ||
      oldDelegate.scrubbing != scrubbing;
}
