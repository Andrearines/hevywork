import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/local/database.dart' show BodyMetric;
import '../../domain/body_metrics.dart';
import '../../domain/measure_series.dart';
import '../../domain/units.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';

/// Sección «Evolución de Medidas» (spec 008, RF-22): pills de serie
/// (Pecho / Cintura / Brazos / Cuádriceps), sparkline con ejes semanales
/// (designer §7.9) y stat boxes de ratio cintura/pecho y crecimiento
/// acumulado. Sin dependencias ni sombras; estado vacío cuando aún no hay
/// evolución que mostrar (RF-37).
class MeasureEvolution extends StatefulWidget {
  final List<BodyMetric> records;

  const MeasureEvolution({super.key, required this.records});

  @override
  State<MeasureEvolution> createState() => _MeasureEvolutionState();
}

class _MeasureEvolutionState extends State<MeasureEvolution> {
  static const _windowDays = 90;

  String _series = kEvolutionMeasures.first;

  DateTime get _today => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final now = DateTime.now();
    final today = _today;
    final points = measureSeries(
      records: widget.records,
      measureId: _series,
      now: now,
      days: _windowDays,
    );

    final checkpoints = measureCheckpoints(widget.records);
    final current = checkpoints.isEmpty ? null : checkpoints.last;
    final previous =
        checkpoints.length > 1 ? checkpoints[checkpoints.length - 2] : null;
    final ratio = current == null ? null : waistToChestRatio(current.measures);
    final ratioDelta = current == null
        ? null
        : waistToChestRatioDelta(
            current: current.measures,
            previous: previous?.measures,
          );
    final growth = cumulativeMeasureGrowth(
      records: widget.records,
      now: now,
      days: _windowDays,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.show_chart,
                size: 18,
                color: kOnSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolución de Medidas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tendencia de las últimas 12 semanas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    for (final id in kEvolutionMeasures)
                      _SeriesPill(
                        label: evolutionMeasureLabel(id),
                        selected: id == _series,
                        onTap: () => setState(() => _series = id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (points.length < 2)
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: const Center(
                      child: Text(
                        'Registra medidas para ver la tendencia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kOnSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _EvolutionPainter(
                          points: points,
                          from: today.subtract(
                            const Duration(days: _windowDays - 1),
                          ),
                          to: today,
                        ),
                      ),
                    ),
                  ),
                  _WeekAxis(now: today, days: _windowDays),
                ],
                const SizedBox(height: 16),
                Container(height: 1, color: kSurfaceContainerHighest),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'RATIO CINTURA/PECHO',
                          value: ratio == null
                              ? '—'
                              : ratio.toStringAsFixed(2),
                          delta: ratioDelta == null
                              ? null
                              : _signed(ratioDelta, digits: 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          label: 'CRECIMIENTO ACUMULADO',
                          value: growth == null
                              ? '—'
                              : '${_signed(displayLengthCm(growth, unitSystem), digits: 1)} '
                                  '${lengthUnitOf(unitSystem)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill de selección de serie (una a la vez), objetivo táctil de 48 dp y
/// sin sombras.
class _SeriesPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SeriesPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? kSurfaceContainerHighest : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: selected ? kOnSurface : kOnSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat box del gráfico: etiqueta en versalitas y valor con delta opcional
/// coloreado por dirección (mismo criterio que los chips de medidas).
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;

  const _StatBox({required this.label, required this.value, this.delta});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deltaColor = delta == null
        ? kOnSurfaceVariant
        : delta!.startsWith('-')
            ? kTertiaryContainer
            : delta!.startsWith('+')
                ? kOnSurface
                : kOnSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: kOnSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: textTheme.titleMedium),
                if (delta != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    delta!,
                    style: textTheme.labelSmall?.copyWith(
                      color: deltaColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiquetas semanales del eje X, alineadas a la fecha de su marca.
class _WeekAxis extends StatelessWidget {
  final DateTime now;
  final int days;

  const _WeekAxis({required this.now, required this.days});

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final ticks = weeklyAxisLabels(now: now, days: days);
    if (ticks.isEmpty) return const SizedBox.shrink();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: days - 1));
    final span = today.difference(from).inDays;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxLeft = math.max(0.0, width - 52);
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              for (final tick in ticks)
                Positioned(
                  left: (span == 0
                          ? 0.0
                          : tick.difference(from).inDays / span * width)
                      .clamp(0.0, maxLeft),
                  child: Text(
                    '${tick.day} ${_months[tick.month - 1]}',
                    style: textTheme.labelSmall?.copyWith(
                      color: kOnSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// «+2.5» / «-0.02» / «0.0»: siempre con signo explícito salvo cero.
String _signed(double value, {required int digits}) {
  final text = value.abs().toStringAsFixed(digits);
  if (value > 0) return '+$text';
  if (value < 0) return '-$text';
  return text;
}

/// Sparkline de una serie según designer §7.9: línea `onSurface` de 2.2 dp
/// con extremos redondos, área con gradiente blanco 18 % → 0 %, guías
/// punteadas `surfaceContainerHighest`, puntos intermedios `outline` y
/// punto final `primary` con borde `surface`.
class _EvolutionPainter extends CustomPainter {
  final List<MeasurePoint> points;
  final DateTime from;
  final DateTime to;

  _EvolutionPainter({
    required this.points,
    required this.from,
    required this.to,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padTop = 14.0;
    const padBottom = 14.0;
    final usable = size.height - padTop - padBottom;
    final values = [for (final p in points) p.value];
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final span = max - min == 0 ? 1.0 : max - min;
    final totalDays = to.difference(from).inDays;

    double yOf(double value) =>
        padTop + usable - ((value - min) / span) * usable;

    Offset at(MeasurePoint p) => Offset(
          totalDays == 0
              ? 0.0
              : p.date.difference(from).inDays / totalDays * size.width,
          yOf(p.value),
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

    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = at(points[i]);
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = kOnSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final area = Path.from(line)
      ..lineTo(at(points.last).dx, size.height)
      ..lineTo(at(points.first).dx, size.height)
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

    for (var i = 1; i < points.length - 1; i++) {
      canvas.drawCircle(at(points[i]), 2.5, Paint()..color = kOutline);
    }
    final last = at(points.last);
    canvas.drawCircle(last, 4, Paint()..color = kPrimary);
    canvas.drawCircle(
      last,
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
    final distance = (to - from).distance;
    if (distance == 0) return;
    final direction = (to - from) / distance;
    var cursor = from;
    var remaining = distance;
    while (remaining > 0) {
      final segment = math.min(dash, remaining);
      canvas.drawLine(cursor, cursor + direction * segment, paint);
      cursor += direction * (segment + gap);
      remaining -= segment + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _EvolutionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}
