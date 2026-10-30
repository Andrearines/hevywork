import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/weight_progress.dart';
import '../theme/colors.dart';

/// Sparkline de la tendencia de peso (spec 006, RF-3; spec 008, RF-23):
/// línea de media móvil, área bajo la curva, guías punteadas, línea de meta
/// discontinua, segmento proyectado al objetivo, puntos intermedios y punto
/// final destacado. Con menos de dos mediciones muestra un aviso.
class WeightTrend extends StatelessWidget {
  final List<({DateTime date, double weightKg})> points;

  /// Meta activa (kg) que se dibuja como línea horizontal discontinua.
  final double? goalKg;

  /// Punto proyectado al plazo de la meta (RF-23); se une con el último
  /// punto real por un segmento discontinuo.
  final ({DateTime date, double weightKg})? projection;

  final double height;

  const WeightTrend({
    super.key,
    required this.points,
    this.goalKg,
    this.projection,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Registra tu peso para ver la tendencia',
            textAlign: TextAlign.center,
            style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WeightTrendPainter(
        sorted,
        goalKg: goalKg,
        projection: projection,
      ),
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  final List<({DateTime date, double weightKg})> points;
  final double? goalKg;
  final ({DateTime date, double weightKg})? projection;

  _WeightTrendPainter(
    this.points, {
    required this.goalKg,
    required this.projection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final p in points) p.weightKg];
    final projectionValue = projection?.weightKg;
    final candidates = <double>[
      ...values,
      ?goalKg,
      ?projectionValue,
    ];
    final min = candidates.reduce(math.min);
    final max = candidates.reduce(math.max);
    final span = max - min == 0 ? 1.0 : max - min;

    const padTop = 14.0;
    const padBottom = 14.0;
    final usable = size.height - padTop - padBottom;

    // El punto proyectado ocupa el borde derecho; los reales se reparten
    // antes si hay proyección.
    final hasProjection = projection != null;
    final plotWidth = hasProjection ? size.width * 0.78 : size.width;

    double yOf(double weight) =>
        padTop + usable - ((weight - min) / span) * usable;

    Offset pointAt(int i) => Offset(
          i == 0 ? 0 : (i / (values.length - 1)) * plotWidth,
          yOf(values[i]),
        );

    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = padTop + usable - fraction * usable;
      _drawDashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        color: kSurfaceContainerHighest,
        dash: 2,
        gap: 3,
        width: 0.75,
      );
    }

    if (goalKg != null) {
      _drawDashedLine(
        canvas,
        Offset(0, yOf(goalKg!)),
        Offset(size.width, yOf(goalKg!)),
        color: kTertiaryContainer,
        dash: 4,
        gap: 3,
        width: 1,
      );
    }

    // La línea dibujada es la tendencia (media móvil) cuando hay puntos
    // de sobra; con series muy cortas la media sería la propia serie.
    final smoothed = points.length > 4 ? movingAverageKg(points) : values;
    final linePaint = Paint()
      ..color = kOnSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final line = Path();
    for (var i = 0; i < smoothed.length; i++) {
      final offset = Offset(
        i == 0 ? 0 : (i / (smoothed.length - 1)) * plotWidth,
        yOf(smoothed[i]),
      );
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(line, linePaint);

    final area = Path.from(line)
      ..lineTo(plotWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
        ).createShader(Offset.zero & size),
    );

    final lastReal = pointAt(values.length - 1);
    if (hasProjection) {
      final target = Offset(size.width, yOf(projection!.weightKg));
      _drawDashedLine(
        canvas,
        lastReal,
        target,
        color: kOutline,
        dash: 3,
        gap: 3,
        width: 1.4,
      );
      canvas.drawCircle(
        target,
        3.5,
        Paint()
          ..color = kSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (var i = 1; i < values.length - 1; i++) {
      canvas.drawCircle(pointAt(i), 2.5, Paint()..color = kOutline);
    }
    canvas.drawCircle(lastReal, 4, Paint()..color = kPrimary);
    canvas.drawCircle(
      lastReal,
      4,
      Paint()
        ..color = kSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to, {
    required Color color,
    required double dash,
    required double gap,
    required double width,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    var distance = (to - from).distance;
    if (distance == 0) return;
    final direction = (to - from) / distance;
    var cursor = from;
    while (distance > 0) {
      final segment = math.min(dash, distance);
      canvas.drawLine(cursor, cursor + direction * segment, paint);
      cursor += direction * (segment + gap);
      distance -= segment + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) {
    if (oldDelegate.goalKg != goalKg) return true;
    if (oldDelegate.projection?.weightKg != projection?.weightKg ||
        oldDelegate.projection?.date != projection?.date) {
      return true;
    }
    final previous = oldDelegate.points;
    if (previous.length != points.length) return true;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].date != points[i].date ||
          previous[i].weightKg != points[i].weightKg) {
        return true;
      }
    }
    return false;
  }
}
