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
const Key chartDateAxisKey = Key('chart-date-axis');
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

@visibleForTesting
class ExerciseProgressChartGeometry {
  final Size size;
  final List<Offset> nodes;
  final Path linePath;
  final Path areaPath;

  ExerciseProgressChartGeometry({
    required this.size,
    required this.nodes,
    required this.linePath,
    required this.areaPath,
  });
}

@visibleForTesting
ExerciseProgressChartGeometry buildExerciseProgressChartGeometry(
  List<ExerciseSessionPoint> points,
  Size size,
) {
  final nodes = <Offset>[];
  if (points.isNotEmpty) {
    final values = points.map((point) => point.value).toList();
    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final span = math.max(0.01, maxVal - minVal);
    const verticalPadding = 20.0;
    final availableHeight = math.max(0.0, size.height - verticalPadding * 2);

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final normalized = (points[i].value - minVal) / span;
      final y = verticalPadding + (1 - normalized) * availableHeight;
      nodes.add(Offset(x, y));
    }
  }

  final linePath = Path();
  if (nodes.isNotEmpty) {
    linePath.moveTo(nodes.first.dx, nodes.first.dy);
    for (final node in nodes.skip(1)) {
      linePath.lineTo(node.dx, node.dy);
    }
  }

  final areaPath = nodes.isEmpty
      ? Path()
      : (Path.from(linePath)
          ..lineTo(nodes.last.dx, size.height)
          ..lineTo(nodes.first.dx, size.height)
          ..close());

  return ExerciseProgressChartGeometry(
    size: size,
    nodes: nodes,
    linePath: linePath,
    areaPath: areaPath,
  );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final unitSystem = UnitSystemScope.of(context);
        final weightUnit = weightUnitOf(unitSystem);
        const plotHeight = 120.0;
        const horizontalPadding = 40.0;
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding * 2,
        );
        final canvasSize = Size(availableWidth, plotHeight);
        final geometry = buildExerciseProgressChartGeometry(points, canvasSize);
        final periodDeltaValue = periodDelta(points);
        final windowDays = progressWindowDays(window);
        final frequency = windowDays == 0
            ? null
            : weeklyFrequency(
                sessionCount: points.length,
                windowDays: windowDays,
              );
        final domainMetric = switch (metric) {
          ProgressMetric.e1rm => ExerciseProgressMetric.e1rm,
          ProgressMetric.load => ExerciseProgressMetric.load,
          ProgressMetric.volume => ExerciseProgressMetric.volume,
        };
        final deltaText = formatChartDeltaKg(
          periodDeltaValue?.absolute ?? 0,
          domainMetric,
          unitSystem,
        );
        final dates = _representativeDates(points);
        final includeYear = points.first.date.year != points.last.date.year;

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
                      if (frequency != null) ...[
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
                                '${formatDisplay(frequency)}x / semana',
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
                    ],
                  ),
                ],
              ),
            ),
            Align(
              child: SizedBox(
                width: availableWidth,
                child: Column(
                  children: [
                    SizedBox(
                      width: availableWidth,
                      height: plotHeight,
                      child: CustomPaint(
                        key: chartPlotKey,
                        painter: _SparklinePainter(
                          points: points,
                          geometry: geometry,
                          window: window,
                          metric: metric,
                        ),
                        size: canvasSize,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        key: chartDateAxisKey,
                        children: [
                          for (var i = 0; i < dates.length; i++)
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: i == 0
                                    ? Alignment.centerLeft
                                    : i == dates.length - 1
                                    ? Alignment.centerRight
                                    : Alignment.center,
                                child: Text(
                                  _formatAxisDate(
                                    dates[i],
                                    includeYear: includeYear,
                                  ),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: kOnSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _metricLabel(ProgressMetric metric, String weightUnit) =>
      switch (metric) {
        ProgressMetric.e1rm => '1RM Estimado',
        ProgressMetric.load => 'Carga Máx ($weightUnit)',
        ProgressMetric.volume => 'Volumen',
      };
}

List<DateTime> _representativeDates(List<ExerciseSessionPoint> points) {
  final uniqueDates = <DateTime>[];
  for (final point in points) {
    final date = point.date;
    if (uniqueDates.isEmpty || !_isSameDay(uniqueDates.last, date)) {
      uniqueDates.add(date);
    }
  }
  if (uniqueDates.length <= 4) return uniqueDates;
  return [
    for (var i = 0; i < 4; i++) uniqueDates[i * (uniqueDates.length - 1) ~/ 3],
  ];
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatAxisDate(DateTime date, {required bool includeYear}) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return includeYear ? '$day/$month/${date.year}' : '$day/$month';
}

bool _samePoints(
  List<ExerciseSessionPoint> first,
  List<ExerciseSessionPoint> second,
) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i].date != second[i].date || first[i].value != second[i].value) {
      return false;
    }
  }
  return true;
}

class _SparklinePainter extends CustomPainter {
  final List<ExerciseSessionPoint> points;
  final ExerciseProgressChartGeometry geometry;
  final ProgressWindow window;
  final ProgressMetric metric;

  _SparklinePainter({
    required this.points,
    required this.geometry,
    required this.window,
    required this.metric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final paint = Paint()..color = kSurfaceContainerLow;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x220061A8), Color(0x000061A8)],
      stops: const [0.0, 1.0],
    );
    final areaPaint = Paint()
      ..shader = areaGradient.createShader(Offset.zero & size);
    canvas.drawPath(geometry.areaPath, areaPaint);

    final strokePaint = Paint()
      ..color = kChartLine
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(geometry.linePath, strokePaint);

    for (final node in geometry.nodes) {
      canvas.drawCircle(node, 3, Paint()..color = kChartNode);
      canvas.drawCircle(
        node,
        3,
        Paint()
          ..color = kChartNodeStroke
          ..strokeWidth = 1.5,
      );
    }

    final highlightedNode = geometry.nodes.last;
    canvas.drawCircle(highlightedNode, 5, Paint()..color = kPrimary);
    canvas.drawCircle(
      highlightedNode,
      5,
      Paint()
        ..color = kSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.geometry.size != geometry.size ||
        oldDelegate.window != window ||
        oldDelegate.metric != metric ||
        !_samePoints(oldDelegate.points, points);
  }
}
