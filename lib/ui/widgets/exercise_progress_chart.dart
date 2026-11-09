import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_enums.dart';

import '../../domain/exercise_stats.dart';

/// Etiquetas para las ventanas del chart
String _windowLabel(ProgressWindow w) => w == ProgressWindow.oneMonth ? '1M' : w == ProgressWindow.threeMonths ? '3M' : w == ProgressWindow.sixMonths ? '6M' : w == ProgressWindow.oneYear ? '1A' : 'Todo';

/// Etiquetas para las métricas del chart
String _metricLabel(ProgressMetric m) => m == ProgressMetric.e1rm ? '1RM Estimado' : m == ProgressMetric.load ? 'Carga Máx (kg)' : 'Volumen';

const Color kOnSurface = Color(0xFF18181B);
const Color kOnSurfaceVariant = Color(0xFF86868B);
const Color kPrimary = Color(0xFF0061A8);
const Color kSurface = Color(0xFFE4E6EB);
const Color kSurfaceContainerHighest = Color(0xFFD1D3D8);
const Color kSurfaceContainerLow = Color(0xFFF0F2F5);

// Palette tokens (colores semánticos, sin locales claros)
const Color kChartLine = Color(0xFF86868B);
const Color kChartNode = Color(0xFF18181B);
const Color kChartNodeStroke = Color(0xFFFFFFFF);
const Color kChartGuide = Color(0xFFC0C0C0);
const Color kChartArea = Color(0x330061A8);

// Keys de test
const Key chartTabVolumeKey = Key('chart-tab-volume');
const Key chartTabLoadKey = Key('chart-tab-load');
const Key chartTabE1rmKey = Key('chart-tab-e1rm');
const Key chartWindowOneMonthKey = Key('chart-window-onemonth');
const Key chartWindowThreeMonthsKey = Key('chart-window-threemonths');
const Key chartWindowSixMonthsKey = Key('chart-window-sixmonths');
const Key chartWindowOneYearKey = Key('chart-window-oneyear');
const Key chartAllKey = Key('chart-all');
const Key chartPlotKey = Key('chart-plot');
const Key insightDeltaKey = Key('insight-delta');
const Key insightFrequencyKey = Key('insight-frequency');

typedef ExerciseSessionPoint = ({DateTime date, double value});

class ExerciseProgressChart extends StatelessWidget {
  final List<ExerciseSessionSummary> sessions;
  final ProgressMetric metric;
  final ProgressWindow window;
  final Function(ProgressMetric) onMetricChanged;
  final Function(ProgressWindow) onWindowChanged;

  const ExerciseProgressChart({
    super.key,
    required this.sessions,
    required this.metric,
    this.window = ProgressWindow.threeMonths,
    required this.onMetricChanged,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final points = _computePoints(sessions, metric, window);
    // Filtrar por ventana usando la función pura de chart_enums
    final filtered = filterByProgressWindow(points, window, now: now);
    return _buildBody(context, filtered, window, now);
  }

  /// Computa puntos a partir de sesiones usando la métrica y ventana dados.
  List<ExerciseSessionPoint> _computePoints(
    List<ExerciseSessionSummary> sessions,
    ProgressMetric metric,
    ProgressWindow window,
  ) {
    final windowDays = progressWindowDays(window);
    final filtered = <ExerciseSessionSummary>[];
    for (final s in sessions) {
      if (windowDays == 0 || s.endedAt.difference(DateTime.now()).inDays <= windowDays) {
        filtered.add(s);
      }
    }
    final points = <ExerciseSessionPoint>[];
    for (final s in filtered) {
      double? v;
      if (metric == ProgressMetric.e1rm) {
        // Max e1RM from sets
        double? best;
        for (final set in s.sets) {
          if (!set.countsForStats) continue;
          final value = set.e1rm;
          if (value == null) continue;
          if (best == null || value > best) best = value;
        }
        v = best;
      }
      if (metric == ProgressMetric.load) {
        // Max weight from sets
        double? best;
        for (final set in s.sets) {
          if (!set.countsForStats) continue;
          if (set.weightKg <= 0 || set.reps <= 0) continue;
          if (best == null || set.weightKg > best) best = set.weightKg;
        }
        v = best;
      }
      if (metric == ProgressMetric.volume) {
        v = s.volumeKg;
      }
      if (v != null) points.add((date: s.endedAt, value: v));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  Widget _buildBody(
    BuildContext context,
    List<ExerciseSessionPoint> points,
    ProgressWindow window,
    DateTime now,
  ) {
    // Estado: sin datos en esta ventana (<2 puntos)
    if (points.length < 2) {
      return _buildNoDataState(context, points, window);
    }

    return _ChartPlot(
      points: points,
      metric: metric,
      window: window,
      onMetricChanged: onMetricChanged,
      onWindowChanged: onWindowChanged,
    );
  }

  Widget _buildNoDataState(BuildContext context, List<ExerciseSessionPoint> points, ProgressWindow window) {
    final windowLabel = _windowLabel(window);
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Sin datos en esta ventana',
          style: const TextStyle(color: kOnSurfaceVariant),
        ),
      );
    }
    // Un solo punto: no hay delta ni frecuencia
    return Center(
      child: Text(
        'Sin datos en esta ventana ($windowLabel)',
        style: const TextStyle(color: kOnSurfaceVariant),
      ),
    );
  }
}

class _ChartPlot extends StatelessWidget {
  final List<ExerciseSessionPoint> points;
  final ProgressMetric metric;
  final ProgressWindow window;
  final Function(ProgressMetric) onMetricChanged;
  final Function(ProgressWindow) onWindowChanged;

  _ChartPlot({
    required this.points,
    required this.metric,
    required this.window,
    required this.onMetricChanged,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final plotHeight = 120.0;
    final paddingLeft = 40.0;
    final paddingRight = 40.0;
    final paddingTop = 20.0;
    final paddingBottom = 20.0;
    final availableWidth = size.width - paddingLeft - paddingRight;
    final availableHeight = plotHeight;

    // Determinar rango de valores para escalado Y
    final values = points.map((p) => p.value).toList();
    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final span = (math.max(0.01, maxVal - minVal)).clamp(0.01, double.infinity);

    // Escala Y
    double yOf(double value) {
      final normalized = (value - minVal) / span;
      return paddingTop + availableHeight - (normalized * availableHeight);
    }

    // Posiciones X: 4 etiquetas fijas según la ventana
    final List<double> xPositions = _computeXPositions(availableWidth);

    // Insights
    final periodDelta = _periodDelta(points);
    final weeklyFrequency = _weeklyFrequency(points, progressWindowDays(window));

    // Etiqueta del delta
    String _deltaLabel(double? absolute) {
      if (absolute == null) return '—';
      if (metric == ProgressMetric.volume) {
        return '+${absolute.toStringAsFixed(0)} kg·sesiones';
      }
      return '+${absolute.toStringAsFixed(1)} kg';
    }

    final double deltaAbs = periodDelta?.absolute ?? 0;
    final String deltaText = _deltaLabel(deltaAbs);

    // Frecuencia media formateada
    String _frequencyLabel(double freq) {
      return '${freq.toStringAsFixed(1)}x / semana';
    }

    final String freqText = _frequencyLabel(weeklyFrequency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: métrica + ventana + insights
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Etiqueta métrica/ventana
              Text(
                _metricLabel(metric) + ' · ${_windowLabel(window)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kOnSurface,
                ),
              ),
              // Insights en chips
              Row(
                children: [
                  // Chip delta
                  Tooltip(
                    message: 'Delta período',
                    child: Container(
                      key: insightDeltaKey,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: kSurfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        deltaText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chip frecuencia
                  Tooltip(
                    message: 'Frecuencia media semanal',
                    child: Container(
                      key: insightFrequencyKey,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: kSurfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        freqText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // CustomPainter del sparkline
        Expanded(
          child: CustomPaint(
            key: chartPlotKey,
            painter: _SparklinePainter(
              points: points,
              minVal: minVal,
              maxVal: maxVal,
              span: span,
              yOf: yOf,
              xPositions: xPositions,
              window: window,
              metric: metric,
              size: Size(availableWidth, availableHeight),
            ),
            size: Size(availableWidth, availableHeight),
          ),
        ),

        // Etiquetas eje X (4 labels): 1M/3M/6M/1A o Todo
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Label inicio
              Transform.translate(
                offset: Offset(paddingLeft - 20, 0),
                child: Text(
                  '1M',
                  style: TextStyle(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
              // Label medio-izq
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth / 3 - 20, 0),
                child: Text(
                  '3M',
                  style: TextStyle(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
              // Label medio-der
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth * 2 / 3 - 20, 0),
                child: Text(
                  '6M',
                  style: TextStyle(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
              // Label fin / "Todo"
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth - 40, 0),
                child: Text(
                  _windowLabel(window),
                  style: TextStyle(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<double> _computeXPositions(double availableWidth) {
    if (points.length <= 1) {
      // Si un solo punto, centrar todas las etiquetas
      final center = availableWidth / 2;
      return [center, center, center, center];
    }
    // Las 4 etiquetas fijas: inicio, 1/3, 2/3, fin
    return [
      0, // inicio
      availableWidth / 3, // 1/3
      availableWidth * 2 / 3, // 2/3
      availableWidth, // fin
    ].map((pos) => pos.toDouble()).toList();
  }

  String _metricLabel(ProgressMetric m) => m == ProgressMetric.e1rm ? '1RM Estimado' : m == ProgressMetric.load ? 'Carga Máx (kg)' : 'Volumen';

  String _windowLabel(ProgressWindow w) => w == ProgressWindow.oneMonth ? '1M' : w == ProgressWindow.threeMonths ? '3M' : w == ProgressWindow.sixMonths ? '6M' : w == ProgressWindow.oneYear ? '1A' : 'Todo';
}

/// Painter propio para el sparkline del chart de progresión.
class _SparklinePainter extends CustomPainter {
  final List<ExerciseSessionPoint> points;
  final double minVal;
  final double maxVal;
  final double span;
  final double Function(double) yOf;
  final List<double> xPositions;
  final ProgressWindow window;
  final ProgressMetric metric;
  final Size size;

  _SparklinePainter({
    required this.points,
    required this.minVal,
    required this.maxVal,
    required this.span,
    required this.yOf,
    required this.xPositions,
    required this.window,
    required this.metric,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      // Fondo neutro sin datos
      final paint = Paint()..color = kSurfaceContainerLow;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Grosor de línea: 2 dp
    const strokeWidth = 2.0;

    // Área gradiente: 22%→0% (de arriba hacia abajo con transparencia)
    final areaPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length ? xPositions[i] : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      if (i == 0) {
        areaPath.moveTo(x, y);
      } else {
        areaPath.lineTo(x, y);
      }
    }
    // Cerrar el área: bajar al final y regresar al inicio (margen inferior)
    final lastY = yOf(points.last.value);
    areaPath.lineTo(xPositions.last, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    // Gradiente del área: de 22% opaco a 0% transparente
    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x220061A8), Color(0x000061A8)],
      stops: [0.0, 1.0],
    );
    final areaPaint = Paint()..shader = areaGradient.createShader(Offset.zero & size);
    canvas.drawPath(areaPath, areaPaint);

    // Línea de conexión de puntos (2 dp)
    final strokePaint = Paint()
      ..color = kChartLine
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length ? xPositions[i] : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, strokePaint);

    // Nodos (puntos) en la línea
    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length ? xPositions[i] : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      // Nodo lleno
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = kChartNode);
      // Contorno del nodo
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = kChartNodeStroke..strokeWidth = 1.5);
    }

    // Nodo final destacado
    canvas.drawCircle(Offset(xPositions.last, lastY), 5, Paint()..color = kPrimary);
    canvas.drawCircle(
      Offset(xPositions.last, lastY),
      5,
      Paint()..color = kSurface..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.minVal != minVal ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.window != window ||
        oldDelegate.metric != metric;
  }
}

/// Calcula el delta período (diferencia entre primer y último valor).
PeriodDelta? _periodDelta(List<ExerciseSessionPoint> points) {
  final sorted = points.toList()..sort((a, b) => a.date.compareTo(b.date));
  if (sorted.length < 2) return null;
  final first = sorted.first;
  final last = sorted.last;
  final absolute = last.value - first.value;
  return PeriodDelta(
    absolute: absolute,
    percent: first.value == 0 ? null : absolute / first.value * 100,
  );
}

/// Calcula la frecuencia media semanal.
double _weeklyFrequency(List<ExerciseSessionPoint> points, int windowDays) {
  if (points.length <= 0 || windowDays <= 0) return 0;
  final sessionCount = points.length;
  return sessionCount / (windowDays / 7);
}