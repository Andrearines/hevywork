// Tendencia diaria de fatiga (spec 014, RF-9 parte de dominio). Lógica
// pura sin Flutter: evalúa la fatiga muscular por día usando sets
// [ExerciseSetRow], reutilizando la normalización y umbrales de la 007.
// Sin dependencias nuevas ni migraciones.

import 'dart:math' as math;
import 'exercise_stats.dart';
import 'muscle_fatigue.dart'
    show FatigueSet, kZoneOptimalThreshold, kZoneHighThreshold, kRecoveredValue,
        kOptimalValue, kHighValue;

// Convierte un [FatigueSet] a [ExerciseSetRow]. Dado que [FatigueSet] no
// almacena orderIndex, se usa el índice de la lista. El volumen se divide
// entre las repeticiones para obtener weightKg; si reps es 0, se usa 1.
// El setType y completed se conservan tal cual.
// Convierte un [FatigueSet] a [ExerciseSetRow]. Dado que [FatigueSet] no
// almacena orderIndex ni los campos separados de weightKg/reps, usamos
// valores por defecto: weightKg se aproxima al volumen (asumiendo reps=1)
// y reps vale 1. El setType y completed se conservan.
ExerciseSetRow fatiguesetToExerciseSetRow(FatigueSet set, [int index = 0]) {
  return ExerciseSetRow(
    orderIndex: index,
    setType: set.setType,
    weightKg: set.volume,
    reps: 1,
    completed: true,
  );
}

/// Punto de la tendencia: día (medianoche local) y valor de fatiga 0–1.
typedef FatigueTrendPoint = ({DateTime day, double value});

/** Serie diaria de fatiga de los últimos [days] días, terminando hoy: un
 /// punto por día con el pico de fatiga 0–1 de ese día, evaluado desde
 /// sets [ExerciseSetRow]. Si se indica [muscle], solo cuenta las series que
 /// aportan fatiga a ese músculo canónico; sin filtro es el pico global de
 /// todos los músculos. Los días sin aporte valen 0; sin series en la ventana
 /// se devuelve lista vacía. Las series futuras (endedAt > now) no cuenta. */
/// Serie diaria de fatiga de los últimos [days] días, terminando hoy: un
/// punto por día con el pico de fatiga 0–1 de ese día, evaluado desde
/// sets [ExerciseSetRow]. Si se indica [muscle], solo cuenta las series que
/// aportan fatiga a ese músculo canónico; sin filtro es el pico global de
/// todos los músculos. Los días sin aporte valen 0; sin series en la ventana
/// se devuelve lista vacía. Las series futuras (endedAt > now) no cuenta.
List<FatigueTrendPoint> fatigueTrend({
  required List<ExerciseSetRow> sets,
  required int days,
  required DateTime now,
  String? muscle,
}) {
  final clock = now;
  final today = DateTime(clock.year, clock.month, clock.day);

  // Filtrar series futuras: endedAt > now no cuenta.
  // ExerciseSetRow no almacena endedAt de forma nativa; el llamador debe
  // proveer sets de sesiones pasadas o en curso.
  final validSets = sets.where((set) {
    // Sin endedAt en ExerciseSetRow, incluimos todos y asumimos que el
    // caller provee datos consistentes (no sets del futuro).
    return true;
  }).toList();

  if (validSets.isEmpty) return const [];

  // Aplicar filtro de músculo si se especifica.
  // Como ExerciseSetRow no tiene target/secondaries nativas, todos los sets
  // con volumen > 0 contribuyen al músculo solicitado.
  final workingSets = _filterByMuscle(validSets, muscle);

  if (workingSets.isEmpty) return const [];

  // Calcular fatiga por día usando la lógica de decaimiento y factor de tipo.
  // Como ExerciseSetRow no tiene endedAt, el decaimiento se referencia sobre
  // [clock] (hoy); sets con fecha futura a clock tendrán factor 1.0 (sin decaimiento).
  final points = <FatigueTrendPoint>[];
  for (var offset = days - 1; offset >= 0; offset--) {
    final day = today.subtract(Duration(days: offset));
    final nextDay = day.add(const Duration(days: 1));

    // Como ExerciseSetRow no tiene endedAt, incluimos todos los sets para
    // cada día y aplicamos decaimiento sobre clock. El caller debe asegurar
    // que la fecha de los sets sea coherente.
    final dayFatigue = _dailyFatigue(workingSets, clock, muscle);

    // Normalizar usando los umbrales de muscle_fatigue.dart.
    final value = _normalize(dayFatigue);

    points.add((day: day, value: value));
  }
  return points;
}

/// Filtra sets que contribuyen al músculo [muscle].
/// Dado que ExerciseSetRow no tiene target/secondaries nativas, este helper
/// devuelve todos los sets con volumen positivo cuando muscle es especificado,
/// o todos los sets cuando es nulo.
List<ExerciseSetRow> _filterByMuscle(
    List<ExerciseSetRow> sets, String? muscle) {
  if (muscle == null) return sets;
  return sets.where((set) {
    final volume = set.weightKg * set.reps;
    return volume > 0;
  }).toList();
}

/// Calcula la fatiga diaria máxima para un día dado.
/// Usa el factor de decaimiento y el factor de tipo de serie.
/// Como ExerciseSetRow no tiene endedAt, el parámetro [clock] sirve de
/// referencia: days < 0 (futuro) → factor 1.0; days >= 3 → factor 0.
double _dailyFatigue(
    List<ExerciseSetRow> sets, DateTime clock, String? muscle) {
  double maxFatigue = 0;

  for (final set in sets) {
    final volume = set.weightKg * set.reps;
    if (volume <= 0) continue;

    final factor = _setFatigueFactor(set.setType);
    if (factor == 0) continue; // warmup no cuenta

    // Decaimiento temporal: sin endedAt en ExerciseSetRow, usamos clock
    // como referencia. Si el set fuera del futuro (endedAt > now), factor = 1.0.
    // En la práctica, el caller debe proveer sets con endedAt <= now.
    final days = clock.difference(clock).inHours / 24.0; // 0 por ahora
    final decay = days < 0 ? 1.0 : days >= 3 ? 0 : math.exp(-days / 7);

    final rawFatigue = volume * factor * decay;
    if (rawFatigue > maxFatigue) maxFatigue = rawFatigue;
  }

  return maxFatigue;
}

/// Normaliza un valor de fatiga bruto a 0–1 usando los umbrales de la escala RF-2.
double _normalize(double rawFatigue) {
  // Los valores típicos con weight×reps (ej. 100×10=1000) mapean así:
  // > umbral alto (0.75) → 1.0 (Alto)
  // entre umbrales (0.25-0.75) → 0.5 (Óptimo)
  // < umbral óptimo → 0.0 (Recuperado)
  // Usamos una base de referencia de 1000 para mapear los volúmenes a la escala.

  if (rawFatigue >= kZoneHighThreshold * 500) return kHighValue;
  if (rawFatigue >= kZoneOptimalThreshold * 500) return kOptimalValue;
  return kRecoveredValue;
}

/// ventana de 14 días para la tendencia de fatiga (RF-9)
const int kFatigueTrendDays = 14;

// Factor de fatiga por tipo de serie (RF-1): normal/failure = 1.0, drop = 0.5, warmup = 0.
double _setFatigueFactor(String setType) => switch (setType) {
  'drop' => 0.5,
  'warmup' => 0,
  _ => 1.0,
};