import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class EqNotch {
  const EqNotch({required this.frequencyHz, required this.gainDb});

  final double frequencyHz;
  final double gainDb;
}

class ParametricEqPad extends StatefulWidget {
  const ParametricEqPad({
    super.key,
    required this.notch,
    required this.onNotchChanged,
    required this.onNotchCleared,
  });

  final EqNotch? notch;
  final ValueChanged<EqNotch> onNotchChanged;
  final VoidCallback onNotchCleared;

  static const double minFrequency = 20;
  static const double maxFrequency = 20000;
  static const double maxGainDb = 12;
  static const double removeTapRadius = 32;

  static double frequencyForX(double x, double width) {
    final t = (x / width).clamp(0.0, 1.0);
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    return math.exp(logMin + t * (logMax - logMin));
  }

  static double xForFrequency(double frequencyHz, double width) {
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    final logF = math.log(frequencyHz.clamp(minFrequency, maxFrequency));
    return ((logF - logMin) / (logMax - logMin)) * width;
  }

  static double gainForY(double y, double height) {
    final t = (y / height).clamp(0.0, 1.0);
    return maxGainDb - t * (2 * maxGainDb);
  }

  static double yForGain(double gainDb, double height) {
    final clamped = gainDb.clamp(-maxGainDb, maxGainDb);
    return ((maxGainDb - clamped) / (2 * maxGainDb)) * height;
  }

  @override
  State<ParametricEqPad> createState() => _ParametricEqPadState();
}

class _ParametricEqPadState extends State<ParametricEqPad> {
  Offset? _dragLocalPosition;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handleDrag(details.localPosition, size),
            onPanUpdate: (details) => _handleDrag(details.localPosition, size),
            onPanEnd: (_) => setState(() => _dragLocalPosition = null),
            onDoubleTapDown: (details) =>
                _handleDoubleTap(details.localPosition, size),
            child: Container(
              decoration: BoxDecoration(
                color: SpaceNotesTheme.card,
                border: Border.all(color: SpaceNotesTheme.hairlineStrong),
              ),
              child: CustomPaint(
                painter: _EqCurvePainter(notch: widget.notch),
                child: _dragLocalPosition != null
                    ? _buildReadout(_dragLocalPosition!, size)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadout(Offset position, Size size) {
    final frequency = ParametricEqPad.frequencyForX(position.dx, size.width);
    final gain = ParametricEqPad.gainForY(position.dy, size.height);
    final freqLabel = frequency >= 1000
        ? '${(frequency / 1000).toStringAsFixed(1)}kHz'
        : '${frequency.toStringAsFixed(0)}Hz';
    final gainLabel = '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}dB';

    final labelY = (position.dy - 28).clamp(0.0, size.height - 20);

    return Positioned(
      left: (position.dx - 40).clamp(0.0, size.width - 80),
      top: labelY,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: SpaceNotesTheme.bg,
            border: Border.all(color: SpaceNotesTheme.hairlineStrong),
          ),
          child: Text(
            '$freqLabel  $gainLabel',
            style: const TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.fg,
            ),
          ),
        ),
      ),
    );
  }

  void _handleDrag(Offset localPosition, Size size) {
    final clamped = Offset(
      localPosition.dx.clamp(0, size.width),
      localPosition.dy.clamp(0, size.height),
    );
    final frequency = ParametricEqPad.frequencyForX(clamped.dx, size.width);
    final gain = ParametricEqPad.gainForY(clamped.dy, size.height);
    setState(() => _dragLocalPosition = clamped);
    widget.onNotchChanged(EqNotch(frequencyHz: frequency, gainDb: gain));
  }

  void _handleDoubleTap(Offset localPosition, Size size) {
    final notch = widget.notch;
    if (notch == null) return;
    final notchX = ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
    final notchY = ParametricEqPad.yForGain(notch.gainDb, size.height);
    final distance = (localPosition - Offset(notchX, notchY)).distance;
    if (distance <= ParametricEqPad.removeTapRadius) {
      widget.onNotchCleared();
    }
  }
}

class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({required this.notch});

  final EqNotch? notch;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = SpaceNotesTheme.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final zeroY = size.height / 2;
    final path = Path()..moveTo(0, zeroY);

    if (notch == null) {
      path.lineTo(size.width, zeroY);
    } else {
      final notchX = ParametricEqPad.xForFrequency(notch!.frequencyHz, size.width);
      final notchY = ParametricEqPad.yForGain(notch!.gainDb, size.height);
      const spread = 60.0;

      for (double x = 0; x <= size.width; x += 2) {
        final distance = (x - notchX).abs();
        final influence = math.exp(-(distance * distance) / (2 * spread * spread));
        final y = zeroY + (notchY - zeroY) * influence;
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    final centerLinePaint = Paint()
      ..color = SpaceNotesTheme.hairline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), centerLinePaint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) =>
      oldDelegate.notch?.frequencyHz != notch?.frequencyHz ||
      oldDelegate.notch?.gainDb != notch?.gainDb;
}
