// Lógica pura de fatiga muscular (spec 007, RF-1 y RF-2).
// Código en inglés; las etiquetas visibles al usuario viven en la UI.

import 'dart:math' as math;

/// Ventana de cálculo de fatiga: 30 días de historial (NFR de la 007).
const int kFatigueWindowDays = 30;

/// Tabla de equivalencias del vocabulario `secondary_muscles` (y de los
/// nombres no normalizados del dataset): cada valor se mapea a un ID canónico
/// en snake_case (RF-4). Los que no tienen región propia en el SVG se
/// adscriben a la más próxima (`hip flexors` → cuádriceps, `rotator cuff` →
/// hombros, `ankles`/`ankle stabilizers` → pies). Alimenta a los músculos
/// secundarios; el primario usa [kTargetMuscleAliases].
const Map<String, String> kMuscleAliases = {
  // Identidad de los músculos dibujados.
  'abdominals': 'abdominals',
  'biceps': 'biceps',
  'calves': 'calves',
  'deltoids': 'deltoids',
  'forearms': 'forearms',
  'glutes': 'glutes',
  'hamstrings': 'hamstrings',
  'lower back': 'lower_back',
  'obliques': 'obliques',
  'quadriceps': 'quadriceps',
  'rhomboids': 'rhomboids',
  'triceps': 'triceps',
  // Nombres no normalizados del dataset (caso límite de la 007): lats,
  // traps, chest, shoulders… se vinculan al mismo ID unificado.
  'chest': 'pectoralis_major',
  'lats': 'latissimus_dorsi',
  'latissimus dorsi': 'latissimus_dorsi',
  'traps': 'trapezius',
  'trapezius': 'trapezius',
  'shoulders': 'deltoids',
  'upper back': 'rhomboids',
  'core': 'abdominals',
  'soleus': 'calves',
  'wrist flexors': 'forearms',
  'wrist extensors': 'forearms',
  'wrists': 'forearms',
  // Grupos sin región propia en el SVG: se adscriben a la zona más próxima.
  'hip flexors': 'quadriceps',
  'rotator cuff': 'deltoids',
  'ankles': 'feet',
  'ankle stabilizers': 'feet',
  'hands': 'hands',
};

/// Tabla de equivalencias del vocabulario `target` (amenda 2026-10-22): el
/// músculo **primario** real de cada ejercicio es su campo `target`, no
/// `muscle_group` (que en el dataset es solo `secondary_muscles[0]`). Este
/// vocabulario es distinto al de [kMuscleAliases] (`pectorals` en vez de
/// `chest`, `delts` en vez de `shoulders`, `quads` en vez de `quadriceps`).
/// Los objetivos sin región propia en el SVG se adscriben a la más próxima;
/// `cardiovascular system` no es un músculo y queda sin zona (no se dibuja).
const Map<String, String> kTargetMuscleAliases = {
  'abs': 'abdominals',
  'abductors': 'glutes',
  'adductors': 'quadriceps',
  'biceps': 'biceps',
  'calves': 'calves',
  'delts': 'deltoids',
  'forearms': 'forearms',
  'glutes': 'glutes',
  'hamstrings': 'hamstrings',
  'lats': 'latissimus_dorsi',
  'levator scapulae': 'trapezius',
  'pectorals': 'pectoralis_major',
  'quads': 'quadriceps',
  'serratus anterior': 'obliques',
  'spine': 'lower_back',
  'traps': 'trapezius',
  'triceps': 'triceps',
  'upper back': 'rhomboids',
};

/// Músculos canónicos con región en el SVG (frente y/o espalda). Los valores
/// de fatiga fuera de este conjunto no se dibujan (RF-4).
const Set<String> kMapMuscles = {
  'abdominals',
  'biceps',
  'calves',
  'deltoids',
  'feet',
  'forearms',
  'glutes',
  'hands',
  'hamstrings',
  'latissimus_dorsi',
  'lower_back',
  'obliques',
  'pectoralis_major',
  'quadriceps',
  'rhomboids',
  'trapezius',
  'triceps',
};

/// Serie de trabajo para la fatiga: volumen crudo (`weight_kg × reps`), el
/// `target` (músculo primario real) y los músculos secundarios del
/// ejercicio. El repositorio resuelve el volumen; el factor de tipo y el
/// decaimiento son del dominio (RF-1). Amenda 2026-10-22: el primario sale
/// de `target`, no de `muscle_group` (que es `secondary_muscles[0]`).
typedef FatigueSet = ({
  DateTime endedAt,
  double volume,
  String setType,
  String target,
  List<String> secondaryMuscles,
});

/// Factor del aporte de un músculo secundario (amenda de secundarios,
/// 2026-10-18): la mitad del principal, con el mismo decaimiento.
const double kSecondaryFatigueFactor = 0.5;

/// Umbral «Óptimo» de la fatiga normalizada (RF-24).
const double kZoneOptimalThreshold = 0.25;

/// Umbral «Alto» de la fatiga normalizada (RF-24).
const double kZoneHighThreshold = 0.75;

/// Valores exactos de la escala frío→rojo (RF-2): el estado de una zona es
/// uno de los tres valores de ancla del gradiente (amenda 2026-10-22).
const double kRecoveredValue = 0.0;
const double kOptimalValue = 0.5;
const double kHighValue = 1.0;

/// Ventanas de estado por rol (amenda 2026-10-22): el aporte principal está
/// en «Alto» el día de la sesión y el día siguiente, en «Óptimo» durante el
/// tercero y en «Recuperado» a partir de ahí; el secundario arranca en
/// «Óptimo» y pasa a «Recuperado» a partir de los dos días de su ventana.
const double kPrimaryHighDays = 2;
const double kPrimaryRecoverDays = 3;
const double kSecondaryRecoverDays = 2;

/// Factor de tipo de serie (RF-1): normal/failure = 1.0, drop = 0.5,
/// warmup = 0. Cualquier tipo desconocido se trata como normal.
double setFatigueFactor(String setType) => switch (setType) {
  'drop' => 0.5,
  'warmup' => 0,
  _ => 1.0,
};

/// Decaimiento temporal (RF-1): e^(-días/7) dentro de la ventana, 0 a partir
/// de los 3 días (recuperación completa). Los sets futuros (reloj desplazado
/// en tests) no decaen.
double fatigueDecayFactor(DateTime now, DateTime endedAt) {
  final days = now.difference(endedAt).inHours / 24.0;
  if (days < 0) return 1.0;
  if (days >= 3) return 0;
  return math.exp(-days / 7);
}

/// Fatiga cruda por músculo canónico (RF-1), sin normalizar. El músculo
/// primario (`target`) aporta su volumen íntegro y cada secundario la mitad
/// (`kSecondaryFatigueFactor`); los objetivos sin zona se descartan.
Map<String, double> rawMuscleFatigue({
  required Iterable<FatigueSet> sets,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final fatigue = <String, double>{};
  for (final set in sets) {
    final canonical = kTargetMuscleAliases[set.target];
    final factor = setFatigueFactor(set.setType);
    if (factor == 0 || set.volume <= 0) continue;
    final decay = fatigueDecayFactor(clock, set.endedAt);
    if (canonical != null) {
      fatigue[canonical] =
          (fatigue[canonical] ?? 0) + set.volume * factor * decay;
    }
    for (final muscle in set.secondaryMuscles) {
      final secondary = kMuscleAliases[muscle];
      if (secondary == null || secondary == canonical) continue;
      fatigue[secondary] =
          (fatigue[secondary] ?? 0) +
          set.volume * factor * decay * kSecondaryFatigueFactor;
    }
  }
  return fatigue;
}

/// Antigüedad en días del último aporte por rol (amenda 2026-10-22): por
/// cada músculo canónico, los días que han pasado desde su última serie en
/// la que fue principal y desde su última serie en la que fue secundario.
/// El tipo de serie con factor 0 (calentamiento) no cuenta; sí cuentan las
/// series de peso corporal, cuyo volumen es 0.
typedef MuscleRoles = ({
  Map<String, double> primary,
  Map<String, double> secondary,
});

MuscleRoles muscleRoles({required Iterable<FatigueSet> sets, DateTime? now}) {
  final clock = now ?? DateTime.now();
  final primary = <String, double>{};
  final secondary = <String, double>{};
  for (final set in sets) {
    if (setFatigueFactor(set.setType) == 0) continue;
    final days = clock.difference(set.endedAt).inMinutes / 1440.0;
    final age = days < 0 ? 0.0 : days;
    final canonical = kTargetMuscleAliases[set.target];
    if (canonical != null) _record(primary, canonical, age);
    for (final muscle in set.secondaryMuscles) {
      final canonicalSecondary = kMuscleAliases[muscle];
      if (canonicalSecondary == null || canonicalSecondary == canonical) {
        continue;
      }
      _record(secondary, canonicalSecondary, age);
    }
  }
  return (primary: primary, secondary: secondary);
}

void _record(Map<String, double> roles, String muscle, double age) {
  final current = roles[muscle];
  if (current == null || age < current) roles[muscle] = age;
}

/// Estado de un músculo principal por su antigüedad (amenda 2026-10-22): el
/// rojo no depende del volumen, solo de cuándo se entrenó.
double primaryFatigueValue(double? ageDays) {
  if (ageDays == null) return kRecoveredValue;
  if (ageDays < kPrimaryHighDays) return kHighValue;
  if (ageDays < kPrimaryRecoverDays) return kOptimalValue;
  return kRecoveredValue;
}

/// Estado de un músculo secundario (amenda 2026-10-24): permanece en
/// «Óptimo» durante su ventana de recuperación, con independencia del
/// volumen; nunca sube a «Alto». Su ventana es más corta que la del
/// principal.
double secondaryFatigueValue(double? ageDays) {
  if (ageDays == null || ageDays >= kSecondaryRecoverDays) {
    return kRecoveredValue;
  }
  return kOptimalValue;
}

/// Fatiga completa de un historial de sets (RF-1/RF-2, amenda 2026-10-24):
/// el estado de cada músculo canónico es el mayor de su rol principal y de
/// su rol secundario. Un músculo con actividad en la ventana se dibuja
/// aunque esté recuperado (0 = frío); los nunca entrenados quedan fuera.
Map<String, double> muscleFatigue({
  required Iterable<FatigueSet> sets,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final roles = muscleRoles(sets: sets, now: clock);
  final muscles = <String>{
    ...roles.primary.keys,
    ...roles.secondary.keys,
  };
  return {
    for (final muscle in muscles)
      muscle: math.max(
        primaryFatigueValue(roles.primary[muscle]),
        secondaryFatigueValue(roles.secondary[muscle]),
      ),
  };
}

/// Zona canónica del mapa con su estado semanal (spec 008, RF-24): volumen
/// `weight_kg × reps` de los últimos 7 días, series completadas y la fatiga
/// normalizada 0–1. La vista de progreso muestra las 17 zonas del mapa.
typedef MuscleZoneStats = ({
  String muscle,
  double weeklyVolume,
  int sets,
  double fatigue,
});

/// Estado en español de una zona según su fatiga normalizada (RF-24):
/// `High` (>0.75), `Optimal` (0.25–0.75) y `Recovering` (≤0.25). En la
/// escala frío→rojo de la leyenda, el rojo es la zona más exigida («Alto»)
/// y el azul la que ya se recuperó («Recuperado»).
enum MuscleZoneStatus { recovering, optimal, high }

/// Clasifica una zona por su fatiga normalizada 0–1 (RF-24).
MuscleZoneStatus zoneStatusOf(double fatigue) {
  if (fatigue > kZoneHighThreshold) return MuscleZoneStatus.high;
  if (fatigue > kZoneOptimalThreshold) return MuscleZoneStatus.optimal;
  return MuscleZoneStatus.recovering;
}

/// Etiqueta en español del estado (solo presentación).
String zoneStatusLabel(MuscleZoneStatus status) => switch (status) {
  MuscleZoneStatus.recovering => 'Recuperado',
  MuscleZoneStatus.optimal => 'Óptimo',
  MuscleZoneStatus.high => 'Alto',
};

/// Desglose semanal por zona (spec 008, RF-24): para cada músculo canónico
/// con actividad en la ventana de 7 días devuelve volumen, series y su
/// fatiga normalizada. Las zonas sin actividad quedan fuera; la vista las
/// rellena con cero. El orden es por volumen descendente. Las series de
/// peso corporal (volumen 0) cuentan como serie.
List<MuscleZoneStats> muscleZoneStats({
  required Iterable<FatigueSet> sets,
  required Map<String, double> normalizedFatigue,
  required DateTime now,
}) {
  final clock = now;
  final since = clock.subtract(const Duration(days: kWeeklyZoneWindowDays));
  final volume = <String, double>{};
  final count = <String, int>{};
  for (final set in sets) {
    if (set.endedAt.isBefore(since)) continue;
    final canonical = kTargetMuscleAliases[set.target];
    if (canonical == null) continue;
    if (setFatigueFactor(set.setType) == 0) continue;
    volume[canonical] = (volume[canonical] ?? 0) + set.volume;
    count[canonical] = (count[canonical] ?? 0) + 1;
  }
  final stats = <MuscleZoneStats>[
    for (final entry in volume.entries)
      (
        muscle: entry.key,
        weeklyVolume: entry.value,
        sets: count[entry.key] ?? 0,
        fatigue: normalizedFatigue[entry.key] ?? 0,
      ),
  ];
  stats.sort((a, b) {
    final byVolume = b.weeklyVolume.compareTo(a.weeklyVolume);
    if (byVolume != 0) return byVolume;
    return a.muscle.compareTo(b.muscle);
  });
  return stats;
}

/// Ventana semanal del desglose de zonas (RF-24).
const int kWeeklyZoneWindowDays = 7;
