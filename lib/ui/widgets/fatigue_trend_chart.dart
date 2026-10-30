/// Sparkline de tendencia de fatiga (0–1) de los últimos 14 días (spec 014, RF-9).
/// Área con gradiente suave, punto final, guías punteadas, sin `BoxShadow`.
/// Contraste con fondo neutro `#292A2D` (sin datos). El widget es inmutable:
/// `shouldRepaint` false con mismos puntos y true con diferente lista o músculo.
import 'dart:math' as math;

import 'package:flutter/material.dart';

// Colores de la escala de fatiga (spec 007, RF-2).
const Color kFatigueCold = Color(0xFF4A90E9);
const Color kFatigueWarm = Color(0xFFF5A623);
const Color kFatigueHot = Color(0xFFD0021B);

// Base neutra para sin datos (spec 007, RF-33).
const Color kMuscleBase = Color(0xFF292A2D);

// Colores de la UI.
const Color kOnSurface = Color(0xFF18181B);
const Color kOnSurfaceVariant = Color(0xFF86868B);
const Color kPrimary = Color(0xFF0061A8);
const Color kSurface = Color(0xFFE4E6EB);

/// Widget público que pinta el área visible.
class FatigueTrendChart extends StatelessWidget {
  final List<double> points;
  final String? muscle;

  const FatigueTrendChart({
    super.key,
    required this.points,
    this.muscle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FatigueTrendPainter(points: points, muscle: muscle),
      size: const Size(double.infinity, 120),
    );
  }
}

/// Painter propio para la sparkline de tendencia de fatiga.
class _FatigueTrendPainter extends CustomPainter {
  final List<double> points;
  final String? muscle;

  _FatigueTrendPainter({
    required this.points,
    this.muscle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      // Estado vacío: fondo neutro con mensaje sutil
      final paint = Paint()..color = kMuscleBase;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Determinar rango de valores para escalado Y
    final maxVal = points.reduce(math.max);
    final minVal = points.reduce(math.min);
    final span = (math.max(0.01, maxVal - minVal)).clamp(0.01, 1.0);

    // Ancho disponible para el gráfico (margen izquierdo y derecho)
    final plotWidth = size.width - 40.0;
    final plotHeight = size.height - 20.0;
    const marginLeft = 20.0;
    const marginBottom = 10.0;

    // Escala Y: mapear valor al alto del gráfico
    double yOf(double value) {
      final normalized = (value - minVal) / span;
      return marginBottom + plotHeight - (normalized * plotHeight);
    }

    // Escala X: distribuir puntos a lo ancho
    double xOf(int index) {
      if (points.length == 1) return marginLeft + plotWidth / 2;
      return marginLeft + index / (points.length - 1) * plotWidth;
    }

    // Dibujar área con gradiente suave
    final areaPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i]);
      if (i == 0) {
        areaPath.moveTo(x, y);
      } else {
        areaPath.lineTo(x, y);
      }
    }
    // Cerrar el área: bajar al final y regresar al inicio
    final lastY = yOf(points.last);
    areaPath.lineTo(marginLeft + plotWidth, lastY);
    areaPath.lineTo(marginLeft, lastY);
    areaPath.close();

    // Pintar el área con gradiente frío→calor
    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x334A90E9), Color(0x004A90E9)],
      stops: [0.0, 1.0],
    );
    final areaPaint = Paint()..shader = areaGradient.createShader(Offset.zero & size);
    canvas.drawPath(areaPath, areaPaint);

    // Dibujar línea de tendencia
    final strokePaint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Usar un gradiente para la línea que va de frío a caliente
    final lineGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [kFatigueCold, kFatigueWarm, kFatigueHot],
    );
    strokePaint..shader = lineGradient.createShader(Offset.zero & size);

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, strokePaint);

    // Dibujar guías horizontales punteadas (0, 0.5, 1)
    const dash = 4.0;
    const gapLine = 4.0;
    final guidePaint = Paint()
      ..color = kOnSurfaceVariant.withOpacity(0.3)
      ..strokeWidth = 1;

    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = marginBottom + plotHeight - (fraction * plotHeight);
      _drawDashedLine(
        canvas,
        Offset(marginLeft, y),
        Offset(marginLeft + plotWidth, y),
        dash: dash,
        gap: gapLine,
        width: 1.0,
      );
    }

    // Dibujar puntos en la línea
    for (var i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i]);
      // Punto lleno
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = kOnSurface);
      // Contorno del punto
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = kSurface..strokeWidth = 2);
    }

    // Punto final destacado (RF-9)
    final lastX = xOf(points.length - 1);
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = kPrimary);
    canvas.drawCircle(
      Offset(lastX, lastY),
      5,
      Paint()..color = kSurface..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to, {
    required double dash,
    required double gap,
    required double width,
  }) {
    final paint = Paint()..color = kOnSurfaceVariant.withOpacity(0.3)..strokeWidth = width;
    final direction = (to - from) / (to - from).distance;
    var cursor = from;
    var remaining = (to - from).distance;
    while (remaining > 0) {
      final segment = math.min(dash, remaining);
      canvas.drawLine(cursor, cursor + direction * segment, paint);
      cursor += direction * (segment + gap);
      remaining -= segment + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _FatigueTrendPainter oldDelegate) {
    return oldDelegate.muscle != muscle || points.length != oldDelegate.points.length ||
        !_pointsEqual(oldDelegate.points, points);
  }

  bool _pointsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}