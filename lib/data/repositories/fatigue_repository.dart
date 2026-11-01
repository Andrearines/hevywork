import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/fatigue_trend.dart';
import '../../domain/muscle_fatigue.dart';
import '../local/database.dart';
import '../util/combine_latest.dart';

/// Terna que alimenta la UI de fatiga (spec 014, RF-8): el mapa del caché,
/// el desglose semanal de zonas y la tendencia diaria de 14 días, todo
/// derivado de las mismas series.
typedef FatiguePanel = ({
  Map<String, double> fatigue,
  List<MuscleZoneStats> zones,
  List<FatigueTrendPoint> trend,
});

/// Cache del mapa de fatiga (spec 007, RF-6): recalcula la fatiga por
/// músculo canónico desde las sesiones terminadas de los últimos 30 días y
/// la guarda en `muscle_fatigue`. La UI solo lee el cache.
class FatigueRepository {
  final AppDatabase _db;

  FatigueRepository(this._db);

  /// Recalcula el cache (RF-6). Se lanza tras cada sync completado, al
  /// cerrar una sesión y al abrir el tab Progreso. El cálculo vive en el
  /// dominio puro (`muscleFatigue`); aquí solo se resuelve el volumen crudo
  /// `weight_kg × reps` de las series completadas. Además de las sesiones
  /// `finished` incluye la `active`, fechando sus series por
  /// `endedAt ?? startedAt` (RF-5 de la 014), de modo que el mapa refleja
  /// el entrenamiento en curso.
  ///
  /// La escritura es por diff (RF-6): solo se insertan, actualizan o borran
  /// las filas cuyo `fatigue`/`raw` cambió; si nada cambia no hay
  /// escrituras ni emisiones a los streams de la UI.
  Future<void> recalculate({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final profile = await _profile();
    final since = clock.subtract(const Duration(days: kFatigueWindowDays));

    final workouts = await _workoutsSince(since);
    final workoutIds = [for (final w in workouts) w.id];

    final sets = await _setsOf(workoutIds);

    final raw = rawMuscleFatigue(sets: sets, now: clock);
    final normalized = muscleFatigue(sets: sets, now: clock);

    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.muscleFatigue,
      )..where((t) => t.localUserId.equals(profile.localUserId))).get();
      final existingByMuscle = {
        for (final row in existing) row.muscle: row,
      };

      final toInsert = <MuscleFatigueCompanion>[];
      final toReplace = <MuscleFatigueRow>[];
      for (final entry in normalized.entries) {
        final rawValue = raw[entry.key] ?? 0;
        final current = existingByMuscle[entry.key];
        // Filas idénticas no se tocan: conservan su `computedAt` y no
        // emiten a `watchFatigue` (RF-6).
        if (current != null &&
            current.fatigue == entry.value &&
            current.raw == rawValue) {
          continue;
        }
        if (current == null) {
          toInsert.add(MuscleFatigueCompanion.insert(
            localUserId: profile.localUserId,
            muscle: entry.key,
            fatigue: entry.value,
            raw: rawValue,
            computedAt: clock,
          ));
        } else {
          toReplace.add(current.copyWith(
            fatigue: entry.value,
            raw: rawValue,
            computedAt: clock,
          ));
        }
      }
      final removed = [
        for (final row in existing)
          if (!normalized.containsKey(row.muscle)) row.muscle,
      ];

      if (toInsert.isEmpty && toReplace.isEmpty && removed.isEmpty) return;

      await _db.batch((batch) {
        batch.insertAll(_db.muscleFatigue, toInsert);
        for (final row in toReplace) {
          batch.replace(_db.muscleFatigue, row);
        }
        if (removed.isNotEmpty) {
          batch.deleteWhere(
            _db.muscleFatigue,
            (t) =>
                t.localUserId.equals(profile.localUserId) &
                t.muscle.isIn(removed),
          );
        }
      });
    });
  }

  /// Frescura del cache (RF-8/H6 de la 014): si no existe ninguna fila o la
  /// más reciente tiene un `computedAt` de más de [maxAge], recalcula una
  /// vez en segundo plano; si está fresco, no hace nada ni escribe.
  Future<void> ensureFresh({
    Duration maxAge = const Duration(minutes: 30),
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final profile = await _profile();
    final rows = await (_db.select(
      _db.muscleFatigue,
    )..where((t) => t.localUserId.equals(profile.localUserId))).get();

    DateTime? latest;
    for (final row in rows) {
      if (latest == null || row.computedAt.isAfter(latest)) {
        latest = row.computedAt;
      }
    }
    if (latest != null && clock.difference(latest) <= maxAge) return;
    await recalculate(now: clock);
  }

  /// Fatiga normalizada por músculo canónico (músculo → 0–1).
  Stream<Map<String, double>> watchFatigue() async* {
    final profile = await _profile();
    yield* (_db.select(_db.muscleFatigue)
          ..where((t) => t.localUserId.equals(profile.localUserId)))
        .watch()
        .map((rows) => {for (final row in rows) row.muscle: row.fatigue});
  }

  /// Fuente única de la sección de fatiga (spec 014, RF-8): combina el
  /// caché del mapa con zonas semanales y tendencia de 14 días derivadas de
  /// las series. Vuelve a emitir cuando cambian las series (workouts/sets)
  /// o cuando cambia el caché (`muscle_fatigue`).
  Stream<FatiguePanel> watchFatiguePanel({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final zonesAndTrend = _db
        .select(_db.workoutSets)
        .join([
          innerJoin(
            _db.workoutExercises,
            _db.workoutExercises.id.equalsExp(
              _db.workoutSets.workoutExerciseId,
            ),
          ),
          innerJoin(
            _db.workouts,
            _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
          ),
          innerJoin(
            _db.exercises,
            _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
          ),
        ])
        .watch()
        .asyncMap((rows) => _zonesAndTrend(rows, clock));
    return combineLatest2(watchFatigue(), zonesAndTrend, (fatigue, rest) => (
          fatigue: fatigue,
          zones: rest.zones,
          trend: rest.trend,
        ));
  }

  /// Desglose semanal por zona (spec 008, RF-24): volumen, series y fatiga
  /// normalizada de los últimos 7 días, ordenado por volumen descendente.
  /// Reutiliza la normalización del cache de 30 días para que el color del
  /// mapa y el estado de la fila salgan de la misma escala. Incluye la
  /// sesión `active` con fecha `endedAt ?? startedAt` (RF-5 de la 014).
  Future<List<MuscleZoneStats>> weeklyZoneStats({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final profile = await _profile();
    final since = clock.subtract(const Duration(days: kWeeklyZoneWindowDays));

    final workouts = await _workoutsSince(since);
    final workoutIds = [for (final w in workouts) w.id];

    final sets = await _setsOf(workoutIds);

    final cacheRows = await (_db.select(
      _db.muscleFatigue,
    )..where((t) => t.localUserId.equals(profile.localUserId))).get();
    final normalized = {for (final row in cacheRows) row.muscle: row.fatigue};

    return muscleZoneStats(
      sets: sets,
      normalizedFatigue: normalized,
      now: clock,
    );
  }

  Future<LocalProfile> _profile() async =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();

  /// Fecha de cierre de una sesión para el cálculo de fatiga (RF-5 de la
  /// 014): `endedAt` si ya terminó; para la sesión en curso, `startedAt`.
  static Expression<DateTime> _endOf($WorkoutsTable t) =>
      coalesce<DateTime>([t.endedAt, t.startedAt]);

  /// Sesiones `finished`/`active` cerradas desde [since] (RF-5 de la 014):
  /// la sesión en curso se fecha por `startedAt` vía [_endOf].
  Future<List<Workout>> _workoutsSince(DateTime since) =>
      (_db.select(_db.workouts)..where(
            (t) =>
                t.status.isIn(['finished', 'active']) &
                _endOf(t).isBiggerOrEqualValue(since),
          ))
          .get();

  /// Series completadas de las sesiones dadas, con el volumen crudo
  /// `weight_kg × reps`. Las series de peso corporal (peso 0) también
  /// cuentan: alimentan el rol del músculo aunque no aporten volumen. La
  /// fecha de cada serie sale de su sesión: `endedAt ?? startedAt`, de modo
  /// que las series de la sesión activa también alimentan el cálculo.
  Future<List<FatigueSet>> _setsOf(List<String> workoutIds) async {
    if (workoutIds.isEmpty) return const [];
    final joined =
        await (_db.select(_db.workoutSets).join([
              innerJoin(
                _db.workoutExercises,
                _db.workoutExercises.id.equalsExp(
                  _db.workoutSets.workoutExerciseId,
                ),
              ),
              innerJoin(
                _db.workouts,
                _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
              ),
              innerJoin(
                _db.exercises,
                _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
              ),
            ])..where(
              _db.workouts.id.isIn(workoutIds) &
                  _db.workouts.status.isIn(['finished', 'active']),
            ))
            .get();
    return _setsFromRows(joined);
  }

  /// Zonas semanales y tendencia diaria para el panel (spec 014, RF-8),
  /// derivadas de las series observadas en [rows] y del caché de
  /// `muscle_fatigue` como escala de normalización.
  Future<({List<MuscleZoneStats> zones, List<FatigueTrendPoint> trend})>
  _zonesAndTrend(List<TypedResult> rows, DateTime clock) async {
    final profile = await _profile();
    final fatigueSets = _setsFromRows(rows);
    // Convierte FatigueSet a ExerciseSetRow para la tendencia de fatiga.
    // Se pierde información de endedAt/secondaries, pero se conserva el volumen
    // y el tipo de serie.
    final exerciseSets = [
      for (int i = 0; i < fatigueSets.length; i++)
        fatiguesetToExerciseSetRow(fatigueSets[i], i),
    ];

    final cacheRows = await (_db.select(
      _db.muscleFatigue,
    )..where((t) => t.localUserId.equals(profile.localUserId))).get();
    final normalized = {for (final row in cacheRows) row.muscle: row.fatigue};

    return (
      zones: muscleZoneStats(
        sets: fatigueSets,
        normalizedFatigue: normalized,
        now: clock,
      ),
      trend: fatigueTrend(
        sets: exerciseSets,
        days: kFatigueTrendDays,
        now: clock,
      ),
    );
  }

  /// Convierte las filas del join `workout_sets → workout_exercises →
  /// workouts → exercises` en [FatigueSet], descartando las series no
  /// completadas o sin repeticiones. La fecha de cada serie sale de su
  /// sesión: `endedAt ?? startedAt`.
  List<FatigueSet> _setsFromRows(List<TypedResult> rows) {
    final sets = <FatigueSet>[];
    for (final row in rows) {
      final set = row.readTable(_db.workoutSets);
      if (!set.completed || set.reps <= 0) continue;
      final workout = row.readTable(_db.workouts);
      sets.add((
        endedAt: workout.endedAt ?? workout.startedAt,
        volume: set.weightKg * set.reps,
        setType: set.setType,
        target: row.readTable(_db.exercises).target,
        secondaryMuscles: _decodeSecondaries(
          row.readTable(_db.exercises).secondaryMuscles,
        ),
      ));
    }
    return sets;
  }

  /// `secondary_muscles` del catálogo como lista (JSON array); vacío si el
  /// valor es null o no es un array válido.
  static List<String> _decodeSecondaries(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return [for (final value in decoded) value.toString()];
      }
    } on FormatException {
      return const [];
    }
    return const [];
  }
}
