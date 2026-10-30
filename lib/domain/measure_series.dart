import '../data/local/database.dart' show BodyMetric;
import 'body_metrics.dart';

// ── Gráfico «Evolución de Medidas» (spec 008, RF-22) ────────────────────
// Series, ejes semanales y stat boxes. Dominio puro: sin Flutter y con
// mensajes solo en las etiquetas visibles.

/// Series del gráfico en el orden de los pills del mockup.
const List<String> kEvolutionMeasures = [
  'chest',
  'waist',
  'arm',
  'thigh',
  'neck',
  'calf',
  'hip',
];

/// Etiqueta corta de cada serie para los pills.
String evolutionMeasureLabel(String id) => switch (id) {
      'chest' => 'Pecho',
      'waist' => 'Cintura',
      'arm' => 'Brazos',
      'thigh' => 'Cuádriceps',
      'neck' => 'Cuello',
      'calf' => 'Pantorrilla',
      'hip' => 'Glúteos',
      _ => measureLabel(id),
    };

/// Punto de una serie: fecha sin hora y valor en cm.
typedef MeasurePoint = ({DateTime date, double value});

/// Serie de una medida dentro de la ventana de `days` días que termina
/// hoy, ordenada por fecha; solo registros con valor para esa medida (sin
/// huecos).
List<MeasurePoint> measureSeries({
  required List<BodyMetric> records,
  required String measureId,
  required DateTime now,
  int days = 90,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(Duration(days: days - 1));
  final points = <MeasurePoint>[];
  for (final record in records) {
    final date = DateTime(record.date.year, record.date.month, record.date.day);
    if (date.isBefore(from) || date.isAfter(today)) continue;
    final value = decodeMeasures(record.measuresJson)[measureId];
    if (value == null) continue;
    points.add((date: date, value: value));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Marcas del eje X: lunes de cada semana dentro de la ventana, como
/// máximo `maxLabels` y repartidos por igual (incluye el primero y el
/// último) para no solaparse a 320 dp.
List<DateTime> weeklyAxisLabels({
  required DateTime now,
  int days = 90,
  int maxLabels = 4,
}) {
  if (maxLabels < 1) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(Duration(days: days - 1));
  var first = from;
  while (first.weekday != DateTime.monday) {
    first = first.add(const Duration(days: 1));
    if (first.isAfter(today)) return const [];
  }
  final mondays = <DateTime>[
    for (var d = first; !d.isAfter(today); d = d.add(const Duration(days: 7)))
      d,
  ];
  if (mondays.length <= maxLabels) return mondays;
  if (maxLabels == 1) return [mondays.first];
  return [
    for (var i = 0; i < maxLabels; i++)
      mondays[(i * (mondays.length - 1) / (maxLabels - 1)).round()],
  ];
}

/// Crecimiento acumulado en la ventana: suma de (último − primero) de cada
/// serie con al menos dos puntos. Null si ninguna serie califica.
double? cumulativeMeasureGrowth({
  required List<BodyMetric> records,
  required DateTime now,
  List<String> measureIds = kEvolutionMeasures,
  int days = 90,
}) {
  var total = 0.0;
  var any = false;
  for (final id in measureIds) {
    final series = measureSeries(
      records: records,
      measureId: id,
      now: now,
      days: days,
    );
    if (series.length < 2) continue;
    total += series.last.value - series.first.value;
    any = true;
  }
  return any ? total : null;
}
