/// Gráfica de barras horizontales de volumen semanal por zona (spec 014, RF-9).
/// Muestra las 6 zonas principales por volumen con guías punteadas, área
/// gradiente frío→calor y punto final. Sin `BoxShadow`, contraste AA.
/// El widget es inmutable: `shouldRepaint` false con mismos datos, true con
/// distinta lista o músculo resaltado.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/muscle_fatigue.dart';
import '../widgets/muscle_map.dart' as mm;

// Colores de la escala de fatiga (spec 007, RF-2).
const Color kFatigueCold = Color(0xFF4A90E9);
const Color kFatigueWarm = Color(0xFFF5A623);
const Color kFatigueHot = Color(0xFFD0021B);

// Base neutra para músculos sin dato (spec 007, RF-33).
const Color kMuscleBase = Color(0xFF292A2D);

// Colores de la UI.
const Color kOnSurface = Color(0xFF18181B);
const Color kOnSurfaceVariant = Color(0xFF86868B);
const Color kPrimary = Color(0xFF0061A8);
const Color kSurface = Color(0xFFE4E6EB);

/// Widget público que pinta el área visible.
class ZoneVolumeChart extends StatelessWidget {
  final List<MuscleZoneStats> zones;
  final String? muscle;
  final bool showBack;

  const ZoneVolumeChart({
    super.key,
    required this.zones,
    this.muscle,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ZoneVolumePainter(zones: zones, muscle: muscle, showBack: showBack),
      size: const Size(double.infinity, 120),
    );
  }
}

/// Painter propio para las barras horizontales de volumen por zona.
class _ZoneVolumePainter extends CustomPainter {
  final List<MuscleZoneStats> zones;
  final String? muscle;
  final bool showBack;

  _ZoneVolumePainter({
    required this.zones,
    required this.muscle,
    required this.showBack,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (zones.isEmpty) {
      // Estado vacío: fondo neutro sutil
      final paint = Paint()..color = kMuscleBase;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Ordenar por volumen y tomar top 6
    final sorted = List<MuscleZoneStats>.from(zones)
      ..sort((a, b) => b.weeklyVolume.compareTo(a.weeklyVolume));
    final top = sorted.take(6).toList();

    if (top.isEmpty) {
      return;
    }

    // Determinar rango de volumen para escalado
    final volumes = top.map((z) => z.weeklyVolume).toList();
    final maxVol = volumes.isNotEmpty ? volumes.reduce(math.max) : 1.0;
    final minVol = volumes.isNotEmpty ? volumes.reduce(math.min) : 0.0;
    final span = math.max(1.0, maxVol - minVol);

    // Ancho disponible para las barras (dejar margen izquierdo/derecho)
    final barWidth = size.width - 40.0;
    final barHeight = 16.0;
    const gap = 6.0;

    // Dibujar guías punteadas horizontales (spec 7.9 del designer)
    const dash = 3.0;
    const gapLine = 3.0;
    final paintDash = Paint()
      ..color = kOnSurfaceVariant.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 0; i < top.length; i++) {
      final y = i * (barHeight + gap) + gap;
      // Línea punteada desde el inicio de la barra
      final volNorm = (top[i].weeklyVolume - minVol) / span;
      final xStart = 20.0;
      final xEnd = 20.0 + volNorm * barWidth;
      _drawDashedLine(
        canvas,
        Offset(xStart, y),
        Offset(xEnd, y),
        dash: dash,
        gap: gapLine,
        width: 1,
      );
    }

    // Dibujar barras y etiquetas
    for (int i = 0; i < top.length; i++) {
      final zone = top[i];
      final y = i * (barHeight + gap) + gap;

      // Color de la barra basado en fatiga
      final fatigueColor = _fatigueColor(zone.fatigue);
      final barX = 20.0;
      final barW = (zone.weeklyVolume - minVol) / span * barWidth;

      // Barra llena - usar Rect simple en lugar de RRect
      final barRect = Rect.fromLTRB(barX, y, barX + barW > barX ? barX + barW : barX + 1, y + barHeight);
      canvas.drawRect(barRect, Paint()..color = fatigueColor);

      // Contorno de la barra
      final borderPaint = Paint()
        ..color = kOnSurfaceVariant.withOpacity(0.2)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawRect(barRect, borderPaint);

      // Etiqueta de nombre (lado izquierdo) - usar TextPainter sobre un rect
      final nameStyle = TextStyle(
        color: kOnSurface,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: mm.muscleLabel(zone.muscle), style: nameStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );
      namePainter.layout(minWidth: 0, maxWidth: double.infinity);
      namePainter.paint(canvas, Offset(4, y + 2));

      // Volumen a la derecha de la barra
      final volStyle = TextStyle(
        color: kOnSurfaceVariant,
        fontSize: 10,
      );
      final volPainter = TextPainter(
        text: TextSpan(
          text: '${zone.weeklyVolume.round()} kg×series',
          style: volStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      volPainter.layout(minWidth: 0, maxWidth: double.infinity);
      volPainter.paint(canvas, Offset(barX + barW + 8, y + 2));

      // Punto final de la barra (indicador de fatiga)
      final pointX = barX + barW;
      final pointY = y + barHeight / 2;
      canvas.drawCircle(Offset(pointX, pointY), 3, Paint()..color = fatigueColor);
    }

    // Resaltar el músculo especificado
    if (muscle != null) {
      final targetZone = top.firstWhere(
        (z) => z.muscle == muscle,
      );
      if (targetZone.muscle.isNotEmpty) {
        final volNorm = (targetZone.weeklyVolume - minVol) / span;
        final barX = 20.0;
        final barW = (targetZone.weeklyVolume - minVol) / span * barWidth;

        // Dibujar rectángulo resaltado detrás de toda la área
        final highlightPaint = Paint()
          ..color = kPrimary.withOpacity(0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTRB(barX, 0, barW > 0 ? barW : 1, size.height),
          highlightPaint,
        );

        // Dibujar contorno alrededor de la zona destacada
        final outlinePaint = Paint()
          ..color = kPrimary
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        final y = sorted.indexOf(targetZone) * (barHeight + gap) + gap;
        if (y >= 0 && y < size.height) {
          canvas.drawLine(
            Offset(20, y),
            Offset(20 + barW, y),
            outlinePaint,
          );
          canvas.drawLine(
            Offset(20 + barW, y),
            Offset(20 + barW, y + barHeight),
            outlinePaint,
          );
          canvas.drawLine(
            Offset(20 + barW, y + barHeight),
            Offset(20, y + barHeight),
            outlinePaint,
          );
          canvas.drawLine(
            Offset(20, y + barHeight),
            Offset(20, y),
            outlinePaint,
          );
        }
      }
    }
  }

  Color _fatigueColor(double fatigue) {
    final v = fatigue.clamp(0.0, 1.0);
    if (v <= 0.5) {
      return Color.lerp(kFatigueCold, kFatigueWarm, v / 0.5)!;
    }
    return Color.lerp(kFatigueWarm, kFatigueHot, (v - 0.5) / 0.5)!;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to, {
    required double dash,
    required double gap,
    required double width,
  }) {
    // El color se establece por llamante o por defecto
    final paint = Paint()..strokeWidth = width;
    final direction = (to - from) / (to - from).distance;
    var cursor = from;
    var remaining = (to - from).distance;
    while (remaining > 0) {
      final segment = math.min(dash, remaining);
      canvas.drawLine(cursor, cursor + direction * segment, paint..color = kOnSurfaceVariant.withOpacity(0.3));
      cursor += direction * (segment + gap);
      remaining -= segment + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneVolumePainter oldDelegate) {
    return oldDelegate.muscle != muscle ||
        oldDelegate.showBack != showBack ||
        !_zonesEqual(oldDelegate.zones, zones);
  }

  bool _zonesEqual(List<MuscleZoneStats> a, List<MuscleZoneStats> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].muscle != b[i].muscle ||
          a[i].weeklyVolume != b[i].weeklyVolume ||
          a[i].sets != b[i].sets ||
          a[i].fatigue != b[i].fatigue) {
        return false;
      }
    }
    return true;
  }
}