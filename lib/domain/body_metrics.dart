import 'dart:convert';

import '../data/local/database.dart' show BodyMetric;

// Lógica pura de medidas corporales (spec 006, RF-1/RF-3).
// Código en inglés; las etiquetas visibles al usuario viven en esta misma
// función, con textos en español (constitución §11).

/// Medidas registradas en cada fecha, en orden de visualización (RF-1:
/// Cuello, Pecho, Brazo, Cintura, Pierna, Pantorrilla), en cm.
const List<String> kBodyMeasures = [
  'neck',
  'chest',
  'arm',
  'waist',
  'thigh',
  'calf',
  'hip',
];

/// Etiqueta visible en español de cada `kBodyMeasures`.
String measureLabel(String id) => switch (id) {
      'neck' => 'Cuello',
      'chest' => 'Pecho',
      'arm' => 'Brazo',
      'waist' => 'Cintura',
      'thigh' => 'Pierna',
      'calf' => 'Pantorrilla',
      'hip' => 'Glúteos',
      _ => id,
    };

/// Valores `measures_json` → mapa de medida → cm. Entradas no numéricas se
/// ignoran; una medida desconocida se descarta al no estar en `kBodyMeasures`.
Map<String, double> decodeMeasures(String? json) {
  if (json == null) return const {};
  final trimmed = json.trim();
  if (trimmed.isEmpty) return const {};
  late final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map<String, dynamic>) return const {};
  return {
    for (final entry in decoded.entries)
      if (entry.value is num) entry.key: (entry.value as num).toDouble(),
  };
}

/// Serializa el mapa de medidas para `measures_json`.
String encodeMeasures(Map<String, double> measures) => jsonEncode(measures);

/// Delta de cada medida frente al registro anterior (RF-3): null si falta en
/// cualquiera de los dos lados.
Map<String, double?> measureDeltas({
  required Map<String, double> current,
  Map<String, double>? previous,
}) {
  return {
    for (final id in kBodyMeasures)
      id: previous == null || current[id] == null || previous[id] == null
          ? null
          : current[id]! - previous[id]!,
  };
}

// ── Sección «Medidas Corporales» (spec 008, RF-25) ──────────────────────
// Etiquetas y métricas al estilo del mockup. Código en inglés; los textos
// visibles al usuario están en español (constitución §11).

/// Nombre de cada medida como en el mockup («Pecho / Torso», «Brazo Izq /
/// Der»…). Difiere de `measureLabel`, que usa el nombre corto de la lista.
String measureMockupLabel(String id) => switch (id) {
      'chest' => 'Pecho / Torso',
      'arm' => 'Brazo Izq / Der',
      'waist' => 'Cintura',
      'thigh' => 'Cuádriceps',
      'calf' => 'Pantorrilla',
      'neck' => 'Cuello',
      'hip' => 'Glúteos',
      _ => id,
    };

/// Subtítulo descriptivo de cada medida (mockup: «Contorno axilar»…).
String measureSubtitle(String id) => switch (id) {
      'chest' => 'Contorno axilar',
      'arm' => 'En flexión 90°',
      'waist' => 'Nivel umbilical',
      'thigh' => 'Punto medio muslo',
      'calf' => 'Perímetro máximo',
      'neck' => 'Perímetro cuello',
      _ => '',
    };

/// Icono Material Symbols de cada medida, en el orden del mockup (RF-25).
String measureIconName(String id) => switch (id) {
      'chest' => 'straighten',
      'arm' => 'sports_gymnastics',
      'waist' => 'adjust',
      'thigh' => 'directions_run',
      'calf' => 'accessibility_new',
      'neck' => 'straighten',
      _ => 'straighten',
    };


/// Fecha y medidas del último chequeo con medidas (RF-25).
typedef BodyMetricCheckpoint = ({
  DateTime date,
  Map<String, double> measures,
});

/// Todos los cheques con medidas, ordenados de más antiguo a más reciente.
List<BodyMetricCheckpoint> measureCheckpoints(List<BodyMetric> records) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final checkpoints = <BodyMetricCheckpoint>[];
  for (final record in sorted) {
    final measures = decodeMeasures(record.measuresJson);
    if (measures.isEmpty) continue;
    checkpoints.add((date: record.date, measures: measures));
  }
  return checkpoints;
}

/// Fecha y medidas del último chequeo con medidas; es el «ÚLTIMO CHEQUEO»
/// del mockup (RF-25). Null si ningún registro tiene medidas.
BodyMetricCheckpoint? latestMeasureCheckpoint(List<BodyMetric> records) {
  final checkpoints = measureCheckpoints(records);
  return checkpoints.isEmpty ? null : checkpoints.last;
}

/// Dirección de una medida para el color del chip del mockup (RF-25).
enum MeasureTrend { up, down, flat }

/// Fila de la sección «Medidas Corporales»: valor actual, delta frente al
/// chequeo anterior y tendencia para colorear el chip (RF-25).
typedef MeasureRow = ({
  String id,
  double value,
  double? delta,
  MeasureTrend trend,
});

/// Construye las filas de medidas del último chequeo, en el orden de
/// `kBodyMeasures`. El delta compara contra el chequeo anterior (el
/// registro con medidas más reciente anterior al actual). Las medidas
/// ausentes en el chequeo actual se omiten (sin huecos).
List<MeasureRow> buildMeasureRows({
  required List<BodyMetric> records,
}) {
  final sorted = [...records]
    ..sort((a, b) => a.date.compareTo(b.date));
  BodyMetric? current;
  BodyMetric? previous;
  for (final record in sorted) {
    if (decodeMeasures(record.measuresJson).isEmpty) continue;
    previous = current;
    current = record;
  }
  if (current == null) return const [];
  final currentMeasures = decodeMeasures(current.measuresJson);
  final previousMeasures = decodeMeasures(previous?.measuresJson);
  final deltas =
      measureDeltas(current: currentMeasures, previous: previousMeasures);
  return [
    for (final id in kBodyMeasures)
      if (currentMeasures[id] != null)
        (
          id: id,
          value: currentMeasures[id]!,
          delta: deltas[id],
          trend: switch (deltas[id]) {
            null => MeasureTrend.flat,
            final d when d > 0 => MeasureTrend.up,
            final d when d < 0 => MeasureTrend.down,
            _ => MeasureTrend.flat,
          },
        ),
  ];
}

/// Etiqueta en español del estado de tendencia (solo presentación).
String measureTrendLabel(MeasureTrend trend) => switch (trend) {
      MeasureTrend.up => 'Sube',
      MeasureTrend.down => 'Baja',
      MeasureTrend.flat => 'Estable',
    };

/// Relación cintura/pecho del chequeo (stat box del mockup): cintura
/// dividida por pecho. Null si falta alguna medida o el pecho es 0.
double? waistToChestRatio(Map<String, double> measures) {
  final waist = measures['waist'];
  final chest = measures['chest'];
  if (waist == null || chest == null || chest == 0) return null;
  return waist / chest;
}

/// Delta de la relación cintura/pecho frente al chequeo anterior. Null si
/// falta en cualquiera de los dos lados.
double? waistToChestRatioDelta({
  required Map<String, double> current,
  Map<String, double>? previous,
}) {
  final now = waistToChestRatio(current);
  final before = previous == null ? null : waistToChestRatio(previous);
  if (now == null || before == null) return null;
  return now - before;
}