String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String buildExportCsv({
  required Iterable<
      ({
        String id,
        String? name,
        String status,
        DateTime startedAt,
        DateTime? endedAt,
      })> workouts,
  required Iterable<
      ({
        DateTime date,
        double? weightKg,
        String? measuresJson,
        String? notes,
      })> metrics,
}) {
  final buffer = StringBuffer()
    ..writeln('workouts')
    ..writeln('id,name,status,started_at,ended_at');
  for (final workout in workouts) {
    buffer.writeln([
      _escapeCsv(workout.id),
      _escapeCsv(workout.name ?? ''),
      _escapeCsv(workout.status),
      workout.startedAt.toIso8601String(),
      workout.endedAt?.toIso8601String() ?? '',
    ].join(','));
  }

  buffer
    ..writeln()
    ..writeln('body_metrics')
    ..writeln('date,weight_kg,measures_json,notes');
  for (final metric in metrics) {
    buffer.writeln([
      metric.date.toIso8601String(),
      metric.weightKg?.toString() ?? '',
      _escapeCsv(metric.measuresJson ?? ''),
      _escapeCsv(metric.notes ?? ''),
    ].join(','));
  }

  return buffer.toString();
}
