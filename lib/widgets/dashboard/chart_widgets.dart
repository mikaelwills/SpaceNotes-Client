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

class DashLineSeries {
  final String label;
  final List<({String x, double y})> data;
  final Color? color;

  const DashLineSeries({
    required this.label,
    required this.data,
    this.color,
  });
}

class DashLineChart extends StatelessWidget {
  final List<DashLineSeries> series;
  final double height;
  final int yTicks;
  final int xLabelStride;

  const DashLineChart({
    super.key,
    required this.series,
    this.height = 240,
    this.yTicks = 4,
    this.xLabelStride = 1,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = series.any((s) => s.data.length >= 2);
    if (!hasData) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'no data',
            style: TextStyle(
              fontFamily: SpaceNotesTheme.fontMono,
              fontSize: 10,
              color: SpaceNotesTheme.muted,
            ),
          ),
        ),
      );
    }

    final palette = [
      SpaceNotesTheme.accent,
      SpaceNotesTheme.offline,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (var i = 0; i < series.length; i++)
                  _LegendChip(
                    label: series[i].label,
                    color: series[i].color ?? palette[i % palette.length],
                  ),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _LineChartPainter(
              series: series,
              palette: palette,
              yTicks: yTicks,
              xLabelStride: xLabelStride,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 2, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 10,
            color: SpaceNotesTheme.muted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DashLineSeries> series;
  final List<Color> palette;
  final int yTicks;
  final int xLabelStride;

  _LineChartPainter({
    required this.series,
    required this.palette,
    required this.yTicks,
    required this.xLabelStride,
  });

  static const double _leftPad = 44;
  static const double _rightPad = 8;
  static const double _topPad = 8;
  static const double _bottomPad = 22;

  @override
  void paint(Canvas canvas, Size size) {
    const plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;
    const plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    double minY = double.infinity;
    double maxY = -double.infinity;
    var maxLen = 0;
    for (final s in series) {
      for (final p in s.data) {
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      if (s.data.length > maxLen) maxLen = s.data.length;
    }
    if (minY == double.infinity || maxLen < 2) return;
    if ((maxY - minY).abs() < 1e-9) {
      minY -= 1;
      maxY += 1;
    }
    final padY = (maxY - minY) * 0.08;
    minY -= padY;
    maxY += padY;
    final rangeY = maxY - minY;

    final gridPaint = Paint()
      ..color = SpaceNotesTheme.hairline
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= yTicks; i++) {
      final t = i / yTicks;
      final y = plotBottom - t * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      final value = minY + t * rangeY;
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(value.abs() >= 100 ? 0 : 2),
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 9,
            color: SpaceNotesTheme.dim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 6);
      tp.paint(canvas, Offset(plotLeft - tp.width - 6, y - tp.height / 2));
    }

    final xLabels = series.first.data.map((d) => d.x).toList();
    for (var i = 0; i < xLabels.length; i++) {
      if (i % xLabelStride != 0 && i != xLabels.length - 1) continue;
      final t = xLabels.length == 1 ? 0.5 : i / (xLabels.length - 1);
      final x = plotLeft + t * plotWidth;
      final tp = TextPainter(
        text: TextSpan(
          text: xLabels[i],
          style: const TextStyle(
            fontFamily: SpaceNotesTheme.fontMono,
            fontSize: 9,
            color: SpaceNotesTheme.dim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, plotBottom + 6),
      );
    }

    for (var s = 0; s < series.length; s++) {
      final data = series[s].data;
      if (data.length < 2) continue;
      final color = series[s].color ?? palette[s % palette.length];
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final t = data.length == 1 ? 0.5 : i / (data.length - 1);
        final x = plotLeft + t * plotWidth;
        final norm = (data[i].y - minY) / rangeY;
        final y = plotBottom - norm * plotHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.series != series || old.yTicks != yTicks;
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
