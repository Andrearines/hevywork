import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_enums.dart';

const Color kOnSurface = Color(0xFF18181B);
const Color kOnSurfaceVariant = Color(0xFF86868B);
const Color kPrimary = Color(0xFF0061A8);
const Color kSurface = Color(0xFFE4E6EB);
const Color kSurfaceContainerHighest = Color(0xFFD1D3D8);
const Color kSurfaceContainerLow = Color(0xFFF0F2F5);

typedef ExerciseSessionPoint = ({DateTime date, double value});
typedef ExerciseSessionSummary = ({String? name, DateTime endedAt, List<double> values});

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
    final points = _filteredPoints(sessions, metric, window);
    return _buildBody(context, points);
  }

  List<ExerciseSessionPoint> _filteredPoints(List<ExerciseSessionSummary> sessions, ProgressMetric metric, ProgressWindow window) {
    final now = DateTime.now();
    int windowDays;
    switch (window) {
      case ProgressWindow.oneMonth: windowDays = 30; break;
      case ProgressWindow.threeMonths: windowDays = 90; break;
      case ProgressWindow.sixMonths: windowDays = 180; break;
      case ProgressWindow.oneYear: windowDays = 365; break;
      case ProgressWindow.all: windowDays = 0; break;
    }
    final filtered = <ExerciseSessionSummary>[];
    for (final s in sessions) {
      if (windowDays == 0 || s.endedAt.difference(now).inDays <= windowDays) filtered.add(s);
    }
    final points = <ExerciseSessionPoint>[];
    for (final s in filtered) {
      double? v;
      if (metric == ProgressMetric.e1rm) v = s.values.isNotEmpty ? s.values.reduce(math.max) : null;
      if (metric == ProgressMetric.load) v = s.values.isNotEmpty ? s.values.reduce(math.max) : null;
      if (metric == ProgressMetric.volume) {
        double sum = 0.0;
        for (final cv in s.values) {
          sum += cv;
        }
        v = s.values.isNotEmpty ? sum : null;
      }
      if (v != null) points.add((date: s.endedAt, value: v));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  Widget _buildBody(BuildContext context, List<ExerciseSessionPoint> points) {
    if (points.isEmpty) {
      return Center(child: Text('Sin datos', style: TextStyle(color: kOnSurfaceVariant)));
    }
    // Muestra los puntos en formato de lista simple
    return ListView(
      children: [
        ListTile(title: Text('Métrica: ${_metricLabel(metric)}'), subtitle: Text('Ventana: ${_windowLabel(window)}')),
        ...points.map((p) => ListTile(title: Text('${p.date.day}/${p.date.month}/${p.date.year}'), subtitle: Text('${p.value.toStringAsFixed(1)}'))).toList(),
      ],
    );
  }

  String _metricLabel(ProgressMetric m) => m == ProgressMetric.e1rm ? '1RM Estimado' : m == ProgressMetric.load ? 'Carga Máx (kg)' : 'Volumen';

  String _windowLabel(ProgressWindow w) => w == ProgressWindow.oneMonth ? '1M' : w == ProgressWindow.threeMonths ? '3M' : w == ProgressWindow.sixMonths ? '6M' : w == ProgressWindow.oneYear ? '1A' : 'Todo';
}
