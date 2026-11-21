import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_enums.dart';

import '../../domain/exercise_stats.dart';
import '../../domain/units.dart';
import '../unit_system_scope.dart';

String _windowLabel(ProgressWindow w) => w == ProgressWindow.oneMonth
    ? '1M'
    : w == ProgressWindow.threeMonths
    ? '3M'
    : w == ProgressWindow.sixMonths
    ? '6M'
    : w == ProgressWindow.oneYear
    ? '1A'
    : 'Todo';

const Color kOnSurface = Color(0xFF18181B);
const Color kOnSurfaceVariant = Color(0xFF86868B);
const Color kPrimary = Color(0xFF0061A8);
const Color kSurface = Color(0xFFE4E6EB);
const Color kSurfaceContainerHighest = Color(0xFFD1D3D8);
const Color kSurfaceContainerLow = Color(0xFFF0F2F5);

const Color kChartLine = Color(0xFF86868B);
const Color kChartNode = Color(0xFF18181B);
const Color kChartNodeStroke = Color(0xFFFFFFFF);
const Color kChartGuide = Color(0xFFC0C0C0);
const Color kChartArea = Color(0x330061A8);

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

List<ExerciseSessionPoint> progressChartPoints(
  Iterable<ExerciseSessionSummary> sessions, {
  required ProgressMetric metric,
  required ProgressWindow window,
  DateTime? now,
}) {
  final domainMetric = switch (metric) {
    ProgressMetric.e1rm => ExerciseProgressMetric.e1rm,
    ProgressMetric.load => ExerciseProgressMetric.load,
    ProgressMetric.volume => ExerciseProgressMetric.volume,
  };
  final nowDate = now ?? DateTime.now();
  return filterByProgressWindow(
    exerciseProgressPoints(sessions, metric: domainMetric),
    window,
    now: nowDate,
  );
}

class ExerciseProgressChart extends StatelessWidget {
  final List<ExerciseSessionSummary> sessions;
  final ProgressMetric metric;
  final ProgressWindow window;
  final DateTime Function()? now;
  final Function(ProgressMetric) onMetricChanged;
  final Function(ProgressWindow) onWindowChanged;

  const ExerciseProgressChart({
    super.key,
    required this.sessions,
    required this.metric,
    this.window = ProgressWindow.threeMonths,
    this.now,
    required this.onMetricChanged,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nowDate = (now ?? DateTime.now)();
    final points = progressChartPoints(
      sessions,
      metric: metric,
      window: window,
      now: nowDate,
    );
    return _buildBody(context, points, window);
  }

  Widget _buildBody(
    BuildContext context,
    List<ExerciseSessionPoint> points,
    ProgressWindow window,
  ) {
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

  Widget _buildNoDataState(
    BuildContext context,
    List<ExerciseSessionPoint> points,
    ProgressWindow window,
  ) {
    final windowLabel = _windowLabel(window);
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Sin datos en esta ventana',
          style: const TextStyle(color: kOnSurfaceVariant),
        ),
      );
    }
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

  const _ChartPlot({
    required this.points,
    required this.metric,
    required this.window,
    required this.onMetricChanged,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final unitSystem = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(unitSystem);
    final plotHeight = 120.0;
    final paddingLeft = 40.0;
    final paddingRight = 40.0;
    final paddingTop = 20.0;
    final availableWidth = size.width - paddingLeft - paddingRight;
    final availableHeight = plotHeight;

    final values = points.map((p) => p.value).toList();
    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final span = (math.max(0.01, maxVal - minVal)).clamp(0.01, double.infinity);

    double yOf(double value) {
      final normalized = (value - minVal) / span;
      return paddingTop + availableHeight - (normalized * availableHeight);
    }

    final List<double> xPositions = _computeXPositions(availableWidth);

    final periodDeltaValue = periodDelta(points);
    final frequency = weeklyFrequency(
      sessionCount: points.length,
      windowDays: progressWindowDays(window),
    );

    final domainMetric = switch (metric) {
      ProgressMetric.e1rm => ExerciseProgressMetric.e1rm,
      ProgressMetric.load => ExerciseProgressMetric.load,
      ProgressMetric.volume => ExerciseProgressMetric.volume,
    };
    final String deltaText = formatChartDeltaKg(
      periodDeltaValue?.absolute ?? 0,
      domainMetric,
      unitSystem,
    );
    final String freqText = '${formatDisplay(frequency)}x / semana';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_metricLabel(metric, weightUnit)} · ${_windowLabel(window)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kOnSurface,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Tooltip(
                      message: 'Delta período',
                      child: Container(
                        key: insightDeltaKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deltaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Tooltip(
                      message: 'Frecuencia media semanal',
                      child: Container(
                        key: insightFrequencyKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          freqText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(
          width: availableWidth,
          height: availableHeight,
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

        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform.translate(
                offset: Offset(paddingLeft - 20, 0),
                child: Text(
                  '1M',
                  style: TextStyle(fontSize: 10, color: kOnSurfaceVariant),
                ),
              ),
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth / 3 - 20, 0),
                child: Text(
                  '3M',
                  style: TextStyle(fontSize: 10, color: kOnSurfaceVariant),
                ),
              ),
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth * 2 / 3 - 20, 0),
                child: Text(
                  '6M',
                  style: TextStyle(fontSize: 10, color: kOnSurfaceVariant),
                ),
              ),
              Transform.translate(
                offset: Offset(paddingLeft + availableWidth - 40, 0),
                child: Text(
                  _windowLabel(window),
                  style: TextStyle(fontSize: 10, color: kOnSurfaceVariant),
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
      final center = availableWidth / 2;
      return [center, center, center, center];
    }
    return [
      0,
      availableWidth / 3,
      availableWidth * 2 / 3,
      availableWidth,
    ].map((pos) => pos.toDouble()).toList();
  }

  String _metricLabel(ProgressMetric m, String weightUnit) =>
      m == ProgressMetric.e1rm
          ? '1RM Estimado'
          : m == ProgressMetric.load
              ? 'Carga Máx ($weightUnit)'
              : 'Volumen';

  String _windowLabel(ProgressWindow w) => w == ProgressWindow.oneMonth
      ? '1M'
      : w == ProgressWindow.threeMonths
          ? '3M'
          : w == ProgressWindow.sixMonths
              ? '6M'
              : w == ProgressWindow.oneYear
                  ? '1A'
                  : 'Todo';
}

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
      final paint = Paint()..color = kSurfaceContainerLow;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    const strokeWidth = 2.0;

    final areaPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length
          ? xPositions[i]
          : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      if (i == 0) {
        areaPath.moveTo(x, y);
      } else {
        areaPath.lineTo(x, y);
      }
    }
    final lastY = yOf(points.last.value);
    areaPath.lineTo(xPositions.last, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x220061A8), Color(0x000061A8)],
      stops: [0.0, 1.0],
    );
    final areaPaint = Paint()
      ..shader = areaGradient.createShader(Offset.zero & size);
    canvas.drawPath(areaPath, areaPaint);

    final strokePaint = Paint()
      ..color = kChartLine
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length
          ? xPositions[i]
          : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, strokePaint);

    for (var i = 0; i < points.length; i++) {
      final x = xPositions.isNotEmpty && i < xPositions.length
          ? xPositions[i]
          : (i * size.width / (points.length - 1)).clamp(0.0, size.width);
      final y = yOf(points[i].value);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = kChartNode);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = kChartNodeStroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawCircle(
      Offset(xPositions.last, lastY),
      5,
      Paint()..color = kPrimary,
    );
    canvas.drawCircle(
      Offset(xPositions.last, lastY),
      5,
      Paint()
        ..color = kSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
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
