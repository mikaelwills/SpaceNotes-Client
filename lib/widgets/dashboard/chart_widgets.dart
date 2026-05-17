import 'package:flutter/material.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

class DashProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final String? trailing;
  final Color? color;

  const DashProgressBar({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final c = color ?? SpaceNotesTheme.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: SnMicroLabel(label)),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 10,
                  color: SpaceNotesTheme.muted,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(SpaceNotesTheme.radiusXs),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: SpaceNotesTheme.bgAlt,
              ),
              FractionallySizedBox(
                widthFactor: clamped,
                child: Container(
                  height: 6,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashSparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color? color;

  const DashSparkline({
    super.key,
    required this.values,
    this.height = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? SpaceNotesTheme.accent,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final norm = (values[i] - minV) / range;
      final y = size.height - (norm * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.08),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.25
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

class DashBarChart extends StatelessWidget {
  final List<({String label, double value})> data;
  final double height;
  final Color? color;

  const DashBarChart({
    super.key,
    required this.data,
    this.height = 140,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);
    final maxV = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final c = color ?? SpaceNotesTheme.accent;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: maxV == 0 ? 0 : data[i].value / maxV,
                        widthFactor: 0.6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.18),
                            border: Border(
                              top: BorderSide(color: c, width: 1.25),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data[i].label,
                    style: const TextStyle(
                      fontFamily: SpaceNotesTheme.fontMono,
                      fontSize: 9,
                      color: SpaceNotesTheme.dim,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (i != data.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
