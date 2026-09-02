import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class EqNotch {
  const EqNotch({required this.frequencyHz, required this.gainDb});

  final double frequencyHz;
  final double gainDb;
}

class ParametricEqPad extends StatelessWidget {
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
    if (width <= 0) return minFrequency;
    final t = (x / width).clamp(0.0, 1.0);
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    return math.exp(logMin + t * (logMax - logMin));
  }

  static double xForFrequency(double frequencyHz, double width) {
    if (width <= 0) return 0;
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    final logF = math.log(frequencyHz.clamp(minFrequency, maxFrequency));
    return ((logF - logMin) / (logMax - logMin)) * width;
  }

  static double gainForY(double y, double height) {
    if (height <= 0) return 0;
    final t = (y / height).clamp(0.0, 1.0);
    return maxGainDb - t * (2 * maxGainDb);
  }

  static double yForGain(double gainDb, double height) {
    if (height <= 0) return 0;
    final clamped = gainDb.clamp(-maxGainDb, maxGainDb);
    return ((maxGainDb - clamped) / (2 * maxGainDb)) * height;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handlePanStart(details.localPosition, size),
            onPanUpdate: (details) => _handlePanUpdate(details.delta, size),
            onDoubleTapDown: (details) =>
                _handleDoubleTap(details.localPosition, size),
            child: Container(
              decoration: BoxDecoration(
                color: SpaceNotesTheme.card,
                border: Border.all(color: SpaceNotesTheme.hairlineStrong),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EqCurvePainter(notch: notch),
                    ),
                  ),
                  if (notch != null)
                    _buildReadout(notch!, size),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadout(EqNotch notch, Size size) {
    final x = ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
    final y = ParametricEqPad.yForGain(notch.gainDb, size.height);
    final freqLabel = notch.frequencyHz >= 1000
        ? '${(notch.frequencyHz / 1000).toStringAsFixed(1)}kHz'
        : '${notch.frequencyHz.toStringAsFixed(0)}Hz';
    final gainLabel =
        '${notch.gainDb >= 0 ? '+' : ''}${notch.gainDb.toStringAsFixed(1)}dB';

    final labelY = (y - 28).clamp(0.0, size.height - 20);

    return Positioned(
      left: (x - 40).clamp(0.0, size.width - 80),
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

  void _handlePanStart(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (notch != null) return;
    final clamped = Offset(
      localPosition.dx.clamp(0.0, size.width),
      localPosition.dy.clamp(0.0, size.height),
    );
    final frequency = ParametricEqPad.frequencyForX(clamped.dx, size.width);
    final gain = ParametricEqPad.gainForY(clamped.dy, size.height);
    onNotchChanged(EqNotch(frequencyHz: frequency, gainDb: gain));
  }

  void _handlePanUpdate(Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final currentNotch = notch;
    if (currentNotch == null) return;

    final currentX = ParametricEqPad.xForFrequency(currentNotch.frequencyHz, size.width);
    final currentY = ParametricEqPad.yForGain(currentNotch.gainDb, size.height);
    final movedX = (currentX + delta.dx).clamp(0.0, size.width);
    final movedY = (currentY + delta.dy).clamp(0.0, size.height);

    final frequency = ParametricEqPad.frequencyForX(movedX, size.width);
    final gain = ParametricEqPad.gainForY(movedY, size.height);
    onNotchChanged(EqNotch(frequencyHz: frequency, gainDb: gain));
  }

  void _handleDoubleTap(Offset localPosition, Size size) {
    final currentNotch = notch;
    if (currentNotch == null) return;
    final notchX = ParametricEqPad.xForFrequency(currentNotch.frequencyHz, size.width);
    final notchY = ParametricEqPad.yForGain(currentNotch.gainDb, size.height);
    final distance = (localPosition - Offset(notchX, notchY)).distance;
    if (distance <= ParametricEqPad.removeTapRadius) {
      onNotchCleared();
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
      const spread = 10.0;

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
