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

  static const List<double> qLevelBandwidths = [0.3, 0.7, 1.3];

  double get bandwidth => qLevelBandwidths[qLevel];

  EqNotch withQLevel(int level) => EqNotch(
        frequencyHz: frequencyHz,
        gainDb: gainDb,
        qLevel: level,
      );
}

class ParametricEqPad extends StatefulWidget {
  const ParametricEqPad({
    super.key,
    required this.notches,
    required this.onNotchChanged,
    required this.onNotchCleared,
    this.bypassed = false,
  });

  final List<EqNotch> notches;

  /// Fires with the notch's index and its new value. An index equal to the
  /// current length means a new notch was placed.
  final void Function(int index, EqNotch notch) onNotchChanged;

  /// Fires with the index of the notch to remove.
  final ValueChanged<int> onNotchCleared;
  final bool bypassed;

  static const double minFrequency = 20;
  static const double maxFrequency = 20000;
  static const double maxGainDb = 12;
  static const double removeTapRadius = 32;
  /// Raise to 2 to re-enable the second band. Everything below this — the
  /// list plumbing, per-band native routing, nearest-dot hit testing — is
  /// already multi-notch; this is the only gate.
  static const int maxNotches = 1;

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

  static const double height = 180;

  @override
  State<ParametricEqPad> createState() => _ParametricEqPadState();
}

class _ParametricEqPadState extends State<ParametricEqPad> {
  /// Which notch the in-flight drag is moving. Null between drags.
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ParametricEqPad.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handlePanStart(details.localPosition, size),
            onPanUpdate: (details) => _handlePanUpdate(details.delta, size),
            onPanEnd: (_) => _handlePanEnd(),
            onPanCancel: _handlePanEnd,
            onDoubleTapDown: (details) =>
                _handleDoubleTap(details.localPosition, size),
            onTapUp: (details) => _handleTapUp(details.localPosition, size),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EqCurvePainter(
                      notches: widget.notches,
                      bypassed: widget.bypassed,
                    ),
                  ),
                ),
                for (final notch in widget.notches) _buildReadout(notch, size),
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

    final qLabel = 'Q ${notch.bandwidth.toStringAsFixed(1)}';

    // A boost reads above the notch, a cut below it, so the label never sits
    // over the curve it describes. Two lines, so allow for both.
    final labelY = notch.gainDb < 0
        ? (y + 14).clamp(0.0, size.height - 32)
        : (y - 40).clamp(0.0, size.height - 32);

    return Positioned(
      left: (x - 40).clamp(0.0, size.width - 80),
      top: labelY,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$freqLabel  $gainLabel',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 11,
                color: widget.bypassed
                    ? SpaceNotesTheme.muted
                    : SpaceNotesTheme.accent,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              qLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SpaceNotesTheme.fontMono,
                fontSize: 10,
                color: widget.bypassed
                    ? SpaceNotesTheme.muted
                    : SpaceNotesTheme.dim,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Index of the notch under [localPosition], or null if the touch landed on
  /// empty pad. Picks the nearest when both are within the radius.
  int? _notchAt(Offset localPosition, Size size) {
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.notches.length; i++) {
      final notch = widget.notches[i];
      final notchX =
          ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
      final notchY = ParametricEqPad.yForGain(notch.gainDb, size.height);
      final distance = (localPosition - Offset(notchX, notchY)).distance;
      if (distance <= ParametricEqPad.removeTapRadius &&
          distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Nearest notch at any distance, unlike [_notchAt] which requires a hit
  /// inside the tap radius.
  int _nearestNotch(Offset localPosition, Size size) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.notches.length; i++) {
      final notch = widget.notches[i];
      final notchX =
          ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
      final notchY = ParametricEqPad.yForGain(notch.gainDb, size.height);
      final distance = (localPosition - Offset(notchX, notchY)).distance;
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _handlePanStart(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final hit = _notchAt(localPosition, size);
    if (hit != null) {
      _draggingIndex = hit;
      return;
    }

    // At capacity, a drag on empty pad grabs the nearest notch rather than
    // doing nothing — otherwise you can only move it by catching the dot.
    if (widget.notches.length >= ParametricEqPad.maxNotches) {
      if (widget.notches.isEmpty) return;
      _draggingIndex = _nearestNotch(localPosition, size);
      return;
    }

    final clamped = Offset(
      localPosition.dx.clamp(0.0, size.width),
      localPosition.dy.clamp(0.0, size.height),
    );
    _draggingIndex = widget.notches.length;
    widget.onNotchChanged(
      widget.notches.length,
      EqNotch(
        frequencyHz: ParametricEqPad.frequencyForX(clamped.dx, size.width),
        gainDb: ParametricEqPad.gainForY(clamped.dy, size.height),
      ),
    );
  }

  void _handlePanUpdate(Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final index = _draggingIndex;
    if (index == null || index >= widget.notches.length) return;
    final current = widget.notches[index];

    final currentX =
        ParametricEqPad.xForFrequency(current.frequencyHz, size.width);
    final currentY = ParametricEqPad.yForGain(current.gainDb, size.height);
    final movedX = (currentX + delta.dx).clamp(0.0, size.width);
    final movedY = (currentY + delta.dy).clamp(0.0, size.height);

    widget.onNotchChanged(
      index,
      EqNotch(
        frequencyHz: ParametricEqPad.frequencyForX(movedX, size.width),
        gainDb: ParametricEqPad.gainForY(movedY, size.height),
        qLevel: current.qLevel,
      ),
    );
  }

  void _handlePanEnd() => _draggingIndex = null;

  void _handleTapUp(Offset localPosition, Size size) {
    final index = _notchAt(localPosition, size);
    if (index == null) return;
    final current = widget.notches[index];
    widget.onNotchChanged(index, current.withQLevel((current.qLevel + 1) % 3));
  }

  void _handleDoubleTap(Offset localPosition, Size size) {
    final index = _notchAt(localPosition, size);
    if (index == null) return;
    widget.onNotchCleared(index);
  }
}

class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({required this.notches, required this.bypassed});

  final List<EqNotch> notches;
  final bool bypassed;

  @override
  void paint(Canvas canvas, Size size) {
    final curveColor = bypassed ? SpaceNotesTheme.muted : SpaceNotesTheme.accent;
    final zeroY = size.height / 2;
    final path = Path()..moveTo(0, zeroY);

    if (notches.isEmpty) {
      path.lineTo(size.width, zeroY);
    } else {
      // Pixels of curve spread per unit of AVAudioUnitEQ bandwidth — the
      // only knob for visual curve width, so it can never drift out of
      // sync with the actual filter Q like a separately hand-tuned
      // constant would.
      const spreadPerBandwidth = 65.0;

      for (double x = 0; x <= size.width; x += 2) {
        // Bands sum, the same way the real filters do.
        var offset = 0.0;
        for (final notch in notches) {
          final notchX =
              ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
          final notchY = ParametricEqPad.yForGain(notch.gainDb, size.height);
          final spread = notch.bandwidth * spreadPerBandwidth;
          final distance = (x - notchX).abs();
          final influence =
              math.exp(-(distance * distance) / (2 * spread * spread));
          offset += (notchY - zeroY) * influence;
        }
        path.lineTo(x, (zeroY + offset).clamp(0.0, size.height));
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
          curveColor.withValues(alpha: 0.16),
          curveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = curveColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    for (final notch in notches) {
      final notchX =
          ParametricEqPad.xForFrequency(notch.frequencyHz, size.width);
      final notchY = ParametricEqPad.yForGain(notch.gainDb, size.height);

      final glowPaint = Paint()
        ..color = curveColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(notchX, notchY), 10, glowPaint);

      final dotPaint = Paint()..color = curveColor;
      canvas.drawCircle(Offset(notchX, notchY), 4.5, dotPaint);

      final ringPaint = Paint()
        ..color = SpaceNotesTheme.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(notchX, notchY), 4.5, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    if (oldDelegate.bypassed != bypassed) return true;
    if (oldDelegate.notches.length != notches.length) return true;
    for (var i = 0; i < notches.length; i++) {
      if (oldDelegate.notches[i].frequencyHz != notches[i].frequencyHz ||
          oldDelegate.notches[i].gainDb != notches[i].gainDb ||
          oldDelegate.notches[i].qLevel != notches[i].qLevel) {
        return true;
      }
    }
    return false;
  }
}
