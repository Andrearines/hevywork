import 'profile_stats.dart' show weekStart;

export 'profile_stats.dart' show weekStart, weekStreak;

/// Un día de la rejilla mensual (RF-7): la fecha, si cae en el mes que se
/// pinta, si hubo sesión completada y el marcador de esa sesión (la inicial
/// de la rutina o un punto).
class CalendarDay {
  final DateTime date;
  final bool inMonth;
  final bool trained;
  final String? marker;
  final bool isToday;

  const CalendarDay({
    required this.date,
    required this.inMonth,
    required this.trained,
    required this.marker,
    required this.isToday,
  });
}

/// Fecha sin hora, para agrupar por día.
DateTime dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// Día de la semana anterior al lunes (para la rejilla): lunes = 0.
int _mondayOffset(DateTime date) => date.weekday - DateTime.monday;

/// Rejilla mensual navegable (RF-7): empieza en lunes y rellena las semanas
/// completas con días de los meses vecinos, para que ninguna quede coja. Los
/// días de fuera del mes se pintan atenuados.
List<CalendarDay> monthGrid(
  DateTime month, {
  Map<DateTime, String> markers = const {},
  DateTime? today,
}) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final start = first.subtract(Duration(days: _mondayOffset(first)));
  final trailing = 7 - _mondayOffset(last) - 1;
  final total = _mondayOffset(first) + last.day + trailing;
  final todayKey = today == null ? null : dayOf(today);

  return [
    for (var i = 0; i < total; i++)
      () {
        final date = start.add(Duration(days: i));
        final key = dayOf(date);
        return CalendarDay(
          date: key,
          inMonth: key.month == month.month && key.year == month.year,
          trained: markers.containsKey(key),
          marker: markers[key],
          isToday: todayKey == key,
        );
      }(),
  ];
}

/// Días con al menos una sesión completada y su marcador (RF-7): la inicial
/// de la rutina o `•` si la sesión no tiene nombre.
Map<DateTime, String> trainedDayMarkers(
  Iterable<({DateTime endedAt, String? routineName})> sessions,
) {
  final markers = <DateTime, String>{};
  for (final session in sessions) {
    final name = session.routineName?.trim();
    markers[dayOf(session.endedAt)] = (name == null || name.isEmpty)
        ? '•'
        : name.substring(0, 1).toUpperCase();
  }
  return markers;
}

/// Nº de sesiones completadas dentro de un mes concreto.
int sessionsInMonth(Iterable<DateTime> sessionEnds, DateTime month) {
  var count = 0;
  for (final endedAt in sessionEnds) {
    if (endedAt.year == month.year && endedAt.month == month.month) count++;
  }
  return count;
}

/// Volumen movido dentro de un mes concreto, a partir de los pares
/// (fecha, volumen) de cada sesión.
double volumeInMonth(
  Iterable<({DateTime date, double volumeKg})> sessions,
  DateTime month,
) {
  var total = 0.0;
  for (final session in sessions) {
    if (session.date.year == month.year && session.date.month == month.month) {
      total += session.volumeKg;
    }
  }
  return total;
}

/// Adherencia de las últimas [weeks] semanas (RF-8): fracción 0–1 de semanas
/// con al menos una sesión. La semana en curso siempre cuenta.
double adherenceRate(
  Iterable<DateTime> sessionEnds,
  DateTime now, {
  int weeks = 4,
}) {
  if (weeks <= 0) return 0;
  final trained = sessionEnds.map(weekStart).toSet();
  var hit = 0;
  var cursor = weekStart(now);
  for (var i = 0; i < weeks; i++) {
    if (trained.contains(cursor)) hit++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return hit / weeks;
}

/// Texto del mes para el selector de calendario, en español.
String monthLabel(DateTime month) {
  const names = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${names[month.month - 1]} ${month.year}';
}
