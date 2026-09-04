import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class EqNotch {
  const EqNotch({
    required this.frequencyHz,
    required this.gainDb,
    this.qLevel = 0,
  });

  final double frequencyHz;
  final double gainDb;
  final int qLevel;

  static const double baseBandwidth = 0.1;

  double get bandwidth => baseBandwidth * math.pow(2, qLevel);

  EqNotch withQLevel(int level) => EqNotch(
        frequencyHz: frequencyHz,
        gainDb: gainDb,
        qLevel: level,
      );
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

  static const double height = 260;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handlePanStart(details.localPosition, size),
            onPanUpdate: (details) => _handlePanUpdate(details.delta, size),
            onDoubleTapDown: (details) =>
                _handleDoubleTap(details.localPosition, size),
            onTapUp: (details) => _handleTapUp(details.localPosition, size),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EqCurvePainter(notch: notch),
                  ),
                ),
                if (notch != null) _buildReadout(notch!, size),
              ],
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

    final labelY = (y - 26).clamp(0.0, size.height - 18);

    return Positioned(
      left: (x - 40).clamp(0.0, size.width - 80),
      top: labelY,
      child: IgnorePointer(
        child: Text(
          '$freqLabel  $gainLabel',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 11,
            color: SpaceNotesTheme.accent,
            letterSpacing: 0.3,
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
    onNotchChanged(EqNotch(
      frequencyHz: frequency,
      gainDb: gain,
      qLevel: notch?.qLevel ?? 0,
    ));
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
    onNotchChanged(EqNotch(
      frequencyHz: frequency,
      gainDb: gain,
      qLevel: currentNotch.qLevel,
    ));
  }

  void _handleTapUp(Offset localPosition, Size size) {
    final currentNotch = notch;
    if (currentNotch == null) return;
    final notchX = ParametricEqPad.xForFrequency(currentNotch.frequencyHz, size.width);
    final notchY = ParametricEqPad.yForGain(currentNotch.gainDb, size.height);
    final distance = (localPosition - Offset(notchX, notchY)).distance;
    if (distance <= ParametricEqPad.removeTapRadius) {
      onNotchChanged(currentNotch.withQLevel((currentNotch.qLevel + 1) % 3));
    }
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
    final zeroY = size.height / 2;
    final path = Path()..moveTo(0, zeroY);
    double? notchX;
    double? notchY;

    if (notch == null) {
      path.lineTo(size.width, zeroY);
    } else {
      notchX = ParametricEqPad.xForFrequency(notch!.frequencyHz, size.width);
      notchY = ParametricEqPad.yForGain(notch!.gainDb, size.height);
      final spread = 40.0 * math.pow(2, notch!.qLevel);

      for (double x = 0; x <= size.width; x += 2) {
        final distance = (x - notchX).abs();
        final influence = math.exp(-(distance * distance) / (2 * spread * spread));
        final y = zeroY + (notchY - zeroY) * influence;
        path.lineTo(x, y);
      }
    }

    final centerLinePaint = Paint()
      ..color = SpaceNotesTheme.hairline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), centerLinePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, zeroY)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SpaceNotesTheme.accent.withValues(alpha: 0.16),
          SpaceNotesTheme.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = SpaceNotesTheme.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    if (notchX != null && notchY != null) {
      final glowPaint = Paint()
        ..color = SpaceNotesTheme.accent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(notchX, notchY), 10, glowPaint);

      final dotPaint = Paint()..color = SpaceNotesTheme.accent;
      canvas.drawCircle(Offset(notchX, notchY), 4.5, dotPaint);

      final ringPaint = Paint()
        ..color = SpaceNotesTheme.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(notchX, notchY), 4.5, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) =>
      oldDelegate.notch?.frequencyHz != notch?.frequencyHz ||
      oldDelegate.notch?.gainDb != notch?.gainDb;
}
