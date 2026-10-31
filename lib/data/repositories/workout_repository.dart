import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/exercise_stats.dart';
import '../../domain/goals.dart' show setVolumeKg;
import '../../domain/previous_sets.dart';
import '../local/database.dart';

/// Encola un cambio local para subirlo a Supabase (RF-11).
typedef MutationEnqueuer = Future<void> Function(
  String operation,
  String targetTable,
  String payloadJson,
);

/// Valores admitidos de `workout_set.set_type` (RF-7).
const Set<String> kSetTypes = {'warmup', 'normal', 'failure', 'drop'};

/// Una serie que no cumple las reglas de la RF-7.
class SetValidationException implements Exception {
  final String message;

  const SetValidationException(this.message);

  @override
  String toString() => message;
}

/// Sesión o serie que ya no admite cambios: solo la sesión `active` se
/// edita (RF-4).
class SessionNotEditableException implements Exception {
  final String message;

  const SessionNotEditableException(this.message);

  @override
  String toString() => message;
}

/// Sesión pasada cuyo borrador no cumple la RF-5 de la spec 012.
class PastWorkoutValidationException implements Exception {
  final String message;

  const PastWorkoutValidationException(this.message);

  @override
  String toString() => message;
}

/// Serie y ejercicio destacados de una sesión terminada (RF-9): nombre y
/// última serie completada (sin calentamientos).
class ExerciseHighlight {
  final String name;
  final double weightKg;
  final int reps;
  final int? rir;

  const ExerciseHighlight({
    required this.name,
    required this.weightKg,
    required this.reps,
    this.rir,
  });
}

/// Resumen de una sesión terminada para el feed de Entrenar (RF-9): duración,
/// nº de series, tonelaje y ejercicios destacados.
class WorkoutSummary {
  final String id;
  final String? routineId;
  final String? title;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final int setCount;
  final double volumeKg;
  final List<ExerciseHighlight> highlights;

  const WorkoutSummary({
    required this.id,
    required this.routineId,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.setCount,
    required this.volumeKg,
    required this.highlights,
  });
}

/// Serie de una sesión pasada en edición (spec 012).
class PastSetDraft {
  final double weightKg;
  final int reps;
  final int rir;
  final String setType;
  final String? routineSetId;

  const PastSetDraft({
    required this.weightKg,
    required this.reps,
    required this.rir,
    this.setType = 'normal',
    this.routineSetId,
  });
}

/// Ejercicio con sus series de una sesión pasada en edición (spec 012).
class PastExerciseDraft {
  final String exerciseId;
  final List<PastSetDraft> sets;

  const PastExerciseDraft({required this.exerciseId, required this.sets});
}

/// Sesión de entrenamiento en curso: creación, ejercicios, series y cierre
/// (RF-5 a RF-10), encolando cada escritura para Supabase (RF-11).
class WorkoutRepository {
  final AppDatabase _db;

  /// Encola cada escritura local para subirla a Supabase (RF-11).
  final MutationEnqueuer? enqueue;

  WorkoutRepository(this._db, {this.enqueue});

  Stream<Workout?> watchActiveWorkout() => (_db.select(
    _db.workouts,
  )..where((t) => t.status.equals('active'))).watchSingleOrNull();

  Stream<Workout?> watchWorkout(String workoutId) => (_db.select(
    _db.workouts,
  )..where((t) => t.id.equals(workoutId))).watchSingleOrNull();

  /// Ejercicios de la sesión en orden, con su ficha del catálogo (RF-6).
  Stream<List<({WorkoutExercise item, Exercise exercise})>> watchExercises(
    String workoutId,
  ) {
    final query =
        _db.select(_db.workoutExercises).join([
            innerJoin(
              _db.exercises,
              _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
            ),
          ])
          ..where(_db.workoutExercises.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm.asc(_db.workoutExercises.orderIndex)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            item: row.readTable(_db.workoutExercises),
            exercise: row.readTable(_db.exercises),
          ),
      ],
    );
  }

  /// Series de la sesión en orden, incluidas las pendientes.
  Stream<List<WorkoutSet>> watchSets(String workoutId) {
    final query =
        _db.select(_db.workoutSets).join([
            innerJoin(
              _db.workoutExercises,
              _db.workoutExercises.id.equalsExp(
                _db.workoutSets.workoutExerciseId,
              ),
            ),
          ])
          ..where(_db.workoutExercises.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm.asc(_db.workoutSets.orderIndex)]);

    return query.watch().map(
      (rows) => [for (final row in rows) row.readTable(_db.workoutSets)],
    );
  }

  /// Sesiones terminadas con sus agregados, de más reciente a más antigua
  /// (RF-9): duración, series completadas, tonelaje y los 3 ejercicios
  /// destacados.
  Stream<List<WorkoutSummary>> watchFinishedWorkouts() {
    final query =
        _db.select(_db.workoutSets).join([
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
          ..where(_db.workouts.status.equals('finished'))
          ..orderBy([OrderingTerm.desc(_db.workouts.endedAt)]);

    return query.watch().map((rows) {
      final byWorkout = <String, _SummaryBuilder>{};
      for (final row in rows) {
        final workout = row.readTable(_db.workouts);
        if (workout.endedAt == null) continue;
        final item = row.readTable(_db.workoutExercises);
        final set = row.readTable(_db.workoutSets);
        byWorkout
            .putIfAbsent(workout.id, () => _SummaryBuilder(workout))
            .addSet(
              exerciseId: item.exerciseId,
              exerciseName: row.readTable(_db.exercises).name,
              exerciseOrder: item.orderIndex,
              set: set,
            );
      }
      final summaries = byWorkout.values.map((b) => b.build()).toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return summaries;
    });
  }

  /// Series completadas de las sesiones terminadas más recientes anteriores a
  /// [before], por ejercicio (RF-13/RF-14 de la 008): alimenta el «previo» de
  /// la tabla de series en vivo. La selección del «previo» vive en el dominio
  /// puro `previous_sets.dart`.
  Future<Map<String, List<PreviousSet>>> previousSets({
    required DateTime before,
  }) async {
    final query =
        _db.select(_db.workoutSets).join([
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
          ])
          ..where(_db.workouts.status.equals('finished'))
          ..where(_db.workouts.endedAt.isSmallerThanValue(before))
          ..where(_db.workoutSets.completed.equals(true));

    final rows = await query.get();
    final history = <HistorySet>[
      for (final row in rows)
        HistorySet(
          exerciseId: row.readTable(_db.workoutExercises).exerciseId,
          sessionEndedAt: row.readTable(_db.workouts).endedAt!,
          setOrderIndex: row.readTable(_db.workoutSets).orderIndex,
          completed: row.readTable(_db.workoutSets).completed,
          setType: row.readTable(_db.workoutSets).setType,
          weightKg: row.readTable(_db.workoutSets).weightKg,
          reps: row.readTable(_db.workoutSets).reps,
          rir: row.readTable(_db.workoutSets).rir ?? 0,
        ),
    ];
    return previousSessionSets(history, before: before);
  }

  /// Crea la sesión activa; si ya había otra, queda abandonada (RF-5, RF-19).
  /// Con [routineId] la sesión nace de una rutina (RF-2 de la 004) y
  /// [name] copia el nombre de la plantilla (solo local, como el descanso).
  Future<Workout> startWorkout({String? routineId, String? name}) async {
    final now = DateTime.now();

    final previous = await (_db.select(
      _db.workouts,
    )..where((t) => t.status.equals('active'))).getSingleOrNull();
    if (previous != null) {
      final abandoned = previous.copyWith(
        status: 'abandoned',
        endedAt: Value(now),
        updatedAt: now,
      );
      await _db.update(_db.workouts).replace(abandoned);
      await _enqueueRow('upsert', 'workouts', _workoutPayload(abandoned));
    }

    final profile = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(1))).getSingle();

    final workout = Workout(
      id: const Uuid().v4(),
      localUserId: profile.localUserId,
      routineId: routineId,
      name: name,
      notes: null,
      startedAt: now,
      endedAt: null,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.workouts).insert(workout);
    await _enqueueRow('upsert', 'workouts', _workoutPayload(workout));
    // RF-9: la sesión activa queda marcada para reanudarse al arrancar.
    await _setMarker(workout.id);
    return workout;
  }

  /// Crea una sesión ya terminada en una fecha pasada (spec 012, RF-4):
  /// workout `finished` con sus ejercicios y series completadas en una sola
  /// transacción; la cola se encola tras confirmar. Lanza
  /// [PastWorkoutValidationException] si el borrador incumple la RF-5.
  Future<Workout> createPastWorkout({
    required DateTime startedAt,
    required Duration duration,
    required List<PastExerciseDraft> exercises,
    String? routineId,
    String? name,
  }) async {
    if (exercises.isEmpty) {
      throw const PastWorkoutValidationException(
        'Añade al menos un ejercicio',
      );
    }
    if (duration.inMinutes < 1 || duration.inMinutes > 720) {
      throw const PastWorkoutValidationException(
        'La duración debe estar entre 1 y 720 minutos',
      );
    }
    if (startedAt.isAfter(DateTime.now())) {
      throw const PastWorkoutValidationException(
        'La hora de inicio no puede ser futura',
      );
    }
    for (final exercise in exercises) {
      if (exercise.sets.isEmpty) {
        throw const PastWorkoutValidationException(
          'Cada ejercicio necesita al menos una serie',
        );
      }
      for (final set in exercise.sets) {
        _validateSet(
          setType: set.setType,
          weightKg: set.weightKg,
          reps: set.reps,
          rir: set.rir,
        );
      }
    }

    final profile = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(1))).getSingle();

    final now = DateTime.now();
    final workout = Workout(
      id: const Uuid().v4(),
      localUserId: profile.localUserId,
      routineId: routineId,
      name: name,
      notes: null,
      startedAt: startedAt,
      endedAt: startedAt.add(duration),
      status: 'finished',
      createdAt: now,
      updatedAt: now,
    );

    final pending = <(String, String, Map<String, dynamic>)>[];
    await _db.transaction(() async {
      await _db.into(_db.workouts).insert(workout);
      pending.add(('upsert', 'workouts', _workoutPayload(workout)));

      var exerciseIndex = 0;
      for (final exercise in exercises) {
        exerciseIndex++;
        final item = WorkoutExercise(
          id: const Uuid().v4(),
          workoutId: workout.id,
          exerciseId: exercise.exerciseId,
          orderIndex: exerciseIndex,
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_db.workoutExercises).insert(item);
        pending.add(('upsert', 'workout_exercises', _exercisePayload(item)));

        var setIndex = 0;
        for (final set in exercise.sets) {
          setIndex++;
          final row = WorkoutSet(
            id: const Uuid().v4(),
            workoutExerciseId: item.id,
            routineSetId: set.routineSetId,
            orderIndex: setIndex,
            setType: set.setType,
            weightKg: _roundKg(set.weightKg),
            reps: set.reps,
            rir: set.rir,
            restSeconds: null,
            completed: true,
            createdAt: now,
            updatedAt: now,
          );
          await _db.into(_db.workoutSets).insert(row);
          pending.add(('upsert', 'workout_sets', _setPayload(row)));
        }
      }
    });

    for (final entry in pending) {
      await _enqueueRow(entry.$1, entry.$2, entry.$3);
    }
    return workout;
  }

  /// Añade un ejercicio a la sesión con el siguiente `order_index` (RF-6).
  /// Los parámetros de objetivo llegan clonados de la rutina (RF-2 de la 004).
  Future<WorkoutExercise> addExercise({
    required String workoutId,
    required String exerciseId,
    int? targetSets,
    int? targetReps,
    int? targetRir,
    double? suggestedWeightKg,
  }) async {
    final existing = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.workoutId.equals(workoutId))).get();
    final orderIndex = existing.isEmpty
        ? 1
        : existing.map((e) => e.orderIndex).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    final item = WorkoutExercise(
      id: const Uuid().v4(),
      workoutId: workoutId,
      exerciseId: exerciseId,
      orderIndex: orderIndex,
      targetSets: targetSets,
      targetReps: targetReps,
      targetRir: targetRir,
      suggestedWeightKg: suggestedWeightKg,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.workoutExercises).insert(item);
    await _enqueueRow('upsert', 'workout_exercises', _exercisePayload(item));
    return item;
  }

  /// Registra una serie de la sesión (RF-7). Con `completed: false` se usa
  /// para precargar las series planificadas de la rutina como pendientes
  /// (RF-2 de la 004).
  Future<WorkoutSet> logSet({
    required String workoutExerciseId,
    required double weightKg,
    required int reps,
    required int rir,
    String setType = 'normal',
    int? restSeconds,
    String? routineSetId,
    bool completed = true,
  }) async {
    _validateSet(setType: setType, weightKg: weightKg, reps: reps, rir: rir);
    final weight = _roundKg(weightKg);

    final existing = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).get();
    final orderIndex = existing.isEmpty
        ? 1
        : existing.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    final set = WorkoutSet(
      id: const Uuid().v4(),
      workoutExerciseId: workoutExerciseId,
      routineSetId: routineSetId,
      orderIndex: orderIndex,
      setType: setType,
      weightKg: weight,
      reps: reps,
      rir: rir,
      restSeconds: restSeconds,
      completed: completed,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.workoutSets).insert(set);
    await _enqueueRow('upsert', 'workout_sets', _setPayload(set));
    return set;
  }

  /// Borra una serie de la sesión `active` y reordena el resto (RF-1 de la
  /// 002). Solo la sesión `active` admite cambios (RF-4).
  Future<void> deleteSet(String setId) async {
    final set = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingleOrNull();
    if (set == null) return;

    final item = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.id.equals(set.workoutExerciseId))).getSingle();
    await _requireActive(item.workoutId);

    await (_db.delete(_db.workoutSets)..where((t) => t.id.equals(setId))).go();
    await _enqueueRow('delete', 'workout_sets', {'id': setId});
    await _reindexSets(set.workoutExerciseId);
  }

  /// Quita un ejercicio de la sesión `active` con sus series y reordena los
  /// ejercicios restantes (RF-2 de la 002).
  Future<void> removeExercise(String workoutExerciseId) async {
    final item = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.id.equals(workoutExerciseId))).getSingleOrNull();
    if (item == null) return;
    await _requireActive(item.workoutId);

    final sets = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).get();
    for (final set in sets) {
      await (_db.delete(
        _db.workoutSets,
      )..where((t) => t.id.equals(set.id))).go();
      await _enqueueRow('delete', 'workout_sets', {'id': set.id});
    }
    await (_db.delete(
      _db.workoutExercises,
    )..where((t) => t.id.equals(workoutExerciseId))).go();
    await _enqueueRow('delete', 'workout_exercises', {'id': workoutExerciseId});
    await _reindexExercises(item.workoutId);
  }

  /// Reemplaza el ejercicio de la sesión `active` por otro empezando de cero
  /// (RF-3 de la 002): descarta sus series y apunta al nuevo ejercicio.
  Future<void> replaceExercise({
    required String workoutExerciseId,
    required String exerciseId,
  }) async {
    final item = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.id.equals(workoutExerciseId))).getSingleOrNull();
    if (item == null) return;
    await _requireActive(item.workoutId);

    final sets = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).get();
    for (final set in sets) {
      await (_db.delete(
        _db.workoutSets,
      )..where((t) => t.id.equals(set.id))).go();
      await _enqueueRow('delete', 'workout_sets', {'id': set.id});
    }

    final updated = item.copyWith(
      exerciseId: exerciseId,
      updatedAt: DateTime.now(),
    );
    await _db.update(_db.workoutExercises).replace(updated);
    await _enqueueRow('upsert', 'workout_exercises', _exercisePayload(updated));
  }

  /// Reasigna `order_index` 1..n a las series de un ejercicio.
  Future<void> _reindexSets(String workoutExerciseId) async {
    final sets =
        await (_db.select(_db.workoutSets)
              ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get();
    for (var i = 0; i < sets.length; i++) {
      await (_db.update(_db.workoutSets)..where((t) => t.id.equals(sets[i].id)))
          .write(WorkoutSetsCompanion(orderIndex: Value(i + 1)));
    }
  }

  /// Reasigna `order_index` 1..n a los ejercicios de una sesión.
  Future<void> _reindexExercises(String workoutId) async {
    final items =
        await (_db.select(_db.workoutExercises)
              ..where((t) => t.workoutId.equals(workoutId))
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get();
    for (var i = 0; i < items.length; i++) {
      await (_db.update(_db.workoutExercises)
            ..where((t) => t.id.equals(items[i].id)))
          .write(WorkoutExercisesCompanion(orderIndex: Value(i + 1)));
    }
  }

  /// Deshace la última serie completada de la sesión `active`: pasa a
  /// `completed = false` sin borrarla (RF-1). Devuelve `null` si no hay
  /// nada que deshacer.
  Future<WorkoutSet?> undoLastSet(String workoutId) async {
    await _requireActive(workoutId);

    final sets = await _setsOfWorkout(workoutId);
    WorkoutSet? last;
    for (final set in sets) {
      if (set.completed) last = set;
    }
    if (last == null) return null;

    final now = DateTime.now();
    final undone = last.copyWith(completed: false, updatedAt: now);
    await _db.update(_db.workoutSets).replace(undone);
    await _enqueueRow('upsert', 'workout_sets', _setPayload(undone));
    return undone;
  }

  /// Edita reps, peso, RIR o tipo de una serie (RF-3): valida como la RF-7,
  /// actualiza `updated_at` y re-encola. Editar una serie pendiente la
  /// vuelve a confirmar. Solo la sesión `active` admite cambios (RF-4).
  Future<WorkoutSet> updateSet({
    required String setId,
    required double weightKg,
    required int reps,
    required int rir,
    String setType = 'normal',
  }) async {
    _validateSet(setType: setType, weightKg: weightKg, reps: reps, rir: rir);

    final set = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingleOrNull();
    if (set == null) {
      throw const SessionNotEditableException('La serie no existe');
    }

    final item = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.id.equals(set.workoutExerciseId))).getSingle();
    await _requireActive(item.workoutId);

    final now = DateTime.now();
    final updated = set.copyWith(
      setType: setType,
      weightKg: _roundKg(weightKg),
      reps: reps,
      rir: Value(rir),
      completed: true,
      updatedAt: now,
    );
    await _db.update(_db.workoutSets).replace(updated);
    await _enqueueRow('upsert', 'workout_sets', _setPayload(updated));
    return updated;
  }

  /// Marca o desmarca una serie como completada desde el checklist en vivo
  /// (RF-1 de la 002). Desmarcar la deja pendiente sin borrarla. Solo la
  /// sesión `active` admite cambios (RF-4).
  Future<WorkoutSet> setSetCompleted(String setId, bool completed) async {
    final set = await (_db.select(
      _db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingleOrNull();
    if (set == null) {
      throw const SessionNotEditableException('La serie no existe');
    }

    final item = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.id.equals(set.workoutExerciseId))).getSingle();
    await _requireActive(item.workoutId);

    final updated = set.copyWith(
      completed: completed,
      updatedAt: DateTime.now(),
    );
    await _db.update(_db.workoutSets).replace(updated);
    await _enqueueRow('upsert', 'workout_sets', _setPayload(updated));
    return updated;
  }

  /// Termina la sesión. Sin series completadas se borra entera y se
  /// confirma; en caso contrario queda `finished` (RF-10).
  /// Devuelve `true` si se guardó y `false` si se descartó.
  Future<bool> finishWorkout(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return false;

    final items = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.workoutId.equals(workoutId))).get();
    final itemIds = [for (final item in items) item.id];
    final sets = itemIds.isEmpty
        ? const <WorkoutSet>[]
        : await (_db.select(
            _db.workoutSets,
          )..where((t) => t.workoutExerciseId.isIn(itemIds))).get();

    if (!sets.any((s) => s.completed)) {
      await _db.transaction(() async {
        if (itemIds.isNotEmpty) {
          await (_db.delete(
            _db.workoutSets,
          )..where((t) => t.workoutExerciseId.isIn(itemIds))).go();
        }
        await (_db.delete(
          _db.workoutExercises,
        )..where((t) => t.workoutId.equals(workoutId))).go();
        await (_db.delete(
          _db.workouts,
        )..where((t) => t.id.equals(workoutId))).go();
      });
      await _enqueueRow('delete', 'workouts', {'id': workoutId});
      await _clearMarker(workoutId);
      return false;
    }

    final now = DateTime.now();
    final finished = workout.copyWith(
      status: 'finished',
      endedAt: Value(now),
      updatedAt: now,
    );
    await _db.update(_db.workouts).replace(finished);
    await _enqueueRow('upsert', 'workouts', _workoutPayload(finished));
    await _clearMarker(workoutId);
    return true;
  }

  /// Abandona la sesión (RF-19 de la 001 / RF-11 de la 002): queda
  /// `abandoned` y deja de ser reanudable. No-op si ya está cerrada.
  Future<void> abandonWorkout(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return;
    if (workout.status != 'active') return;

    final now = DateTime.now();
    final abandoned = workout.copyWith(
      status: 'abandoned',
      endedAt: Value(now),
      updatedAt: now,
    );
    await _db.update(_db.workouts).replace(abandoned);
    await _enqueueRow('upsert', 'workouts', _workoutPayload(abandoned));
    await _clearMarker(workoutId);
  }

  /// Borra una sesión terminada del historial (RF-12 de la 002): elimina el
  /// workout con sus ejercicios y series en local y re-encola el borrado del
  /// workout (los hijos los elimina la cascada remota). No-op con la sesión
  /// `active`.
  Future<void> deleteWorkout(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return;
    if (workout.status == 'active') return;

    final items = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.workoutId.equals(workoutId))).get();
    final itemIds = [for (final item in items) item.id];
    await _db.transaction(() async {
      if (itemIds.isNotEmpty) {
        await (_db.delete(
          _db.workoutSets,
        )..where((t) => t.workoutExerciseId.isIn(itemIds))).go();
      }
      await (_db.delete(
        _db.workoutExercises,
      )..where((t) => t.workoutId.equals(workoutId))).go();
      await (_db.delete(
        _db.workouts,
      )..where((t) => t.id.equals(workoutId))).go();
    });
    await _enqueueRow('delete', 'workouts', {'id': workoutId});
  }

  /// Historial paginado de sesiones terminadas para un ejercicio concreto
  /// (RF-14 de la 015): pagina por sesiones con offset/límite, solo
  /// `status = 'finished'` con `endedAt != null`, ordena `endedAt desc`. Las
  /// warmups aparecen en la fila pero están marcadas con "(Cal.)" en la
  /// columna SET.
  Future<List<ExerciseSessionSummary>> exerciseHistory({
    required String exerciseId,
    required int limit,
    int offset = 0,
  }) async {
    if (limit <= 0 || offset < 0) return const [];

    final exerciseItems = _db.selectOnly(_db.workoutExercises)
      ..addColumns([_db.workoutExercises.workoutId])
      ..where(_db.workoutExercises.exerciseId.equals(exerciseId));

    final workouts = await (_db.select(_db.workouts)
          ..where((t) => t.id.isInQuery(exerciseItems))
          ..where((t) => t.status.equals('finished'))
          ..where((t) => t.endedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.endedAt)])
          ..limit(limit, offset: offset))
        .get();
    if (workouts.isEmpty) return const [];

    final workoutIds = [for (final workout in workouts) workout.id];

    final setsRows = await (_db.select(_db.workoutSets).join([
          innerJoin(
            _db.workoutExercises,
            _db.workoutExercises.id.equalsExp(
              _db.workoutSets.workoutExerciseId,
            ),
          ),
        ])
          ..where(_db.workoutExercises.exerciseId.equals(exerciseId))
          ..where(_db.workoutExercises.workoutId.isIn(workoutIds)))
        .get();

    final setsByWorkout = <String, List<WorkoutSet>>{};
    for (final row in setsRows) {
      final item = row.readTable(_db.workoutExercises);
      final set = row.readTable(_db.workoutSets);
      (setsByWorkout[item.workoutId] ??= []).add(set);
    }
    for (final sets in setsByWorkout.values) {
      sets.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    final summaries = <ExerciseSessionSummary>[];
    for (final workout in workouts) {
      final rows = <ExerciseSetRow>[];
      for (final set in setsByWorkout[workout.id] ?? const <WorkoutSet>[]) {
        rows.add(ExerciseSetRow(
          orderIndex: set.orderIndex,
          setType: set.setType,
          weightKg: set.weightKg,
          reps: set.reps,
          rir: set.rir,
          completed: set.completed,
        ));
      }
      summaries.add(ExerciseSessionSummary(
        workoutId: workout.id,
        name: workout.name ?? 'Sesión',
        endedAt: workout.endedAt!,
        sets: rows,
      ));
    }
    return summaries;
  }

  /// Devuelve la sesión reanudable del marcador (RF-10): `active` sin
  /// `ended_at`. Si el marcador está huérfano (sesión cerrada o borrada) lo
  /// limpia y devuelve null.
  Future<Workout?> restoreLastActiveWorkout() async {
    final profile = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(1))).getSingle();
    final marker = profile.lastActiveWorkoutId;
    if (marker == null) return null;

    final workout = await (_db.select(
      _db.workouts,
    )..where((t) => t.id.equals(marker))).getSingleOrNull();
    if (workout == null ||
        workout.status != 'active' ||
        workout.endedAt != null) {
      await _clearMarker(marker);
      return null;
    }
    return workout;
  }

  /// Guarda el marcador de reanudación (RF-9). Nunca se sincroniza: es
  /// estado local del perfil.
  Future<void> _setMarker(String workoutId) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(lastActiveWorkoutId: Value(workoutId)),
    );
  }

  Future<void> _clearMarker(String workoutId) async {
    final profile = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(1))).getSingle();
    if (profile.lastActiveWorkoutId != workoutId) return;
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      const LocalProfilesCompanion(lastActiveWorkoutId: Value(null)),
    );
  }

  /// Valida una serie según la RF-7.
  void _validateSet({
    required String setType,
    required double weightKg,
    required int reps,
    required int rir,
  }) {
    if (!kSetTypes.contains(setType)) {
      throw SetValidationException('Tipo de serie no válido: $setType');
    }
    if (reps < 1) {
      throw const SetValidationException('Las repeticiones deben ser 1 o más');
    }
    if (weightKg < 0) {
      throw const SetValidationException('El peso no puede ser negativo');
    }
    if (rir < 0 || rir > 10) {
      throw const SetValidationException('El RIR debe estar entre 0 y 10');
    }
  }

  /// Redondea a 0.001 kg (caso límite de la 001).
  double _roundKg(double weightKg) => (weightKg * 1000).roundToDouble() / 1000;

  Future<Workout> _requireActive(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) {
      throw const SessionNotEditableException('La sesión no existe');
    }
    if (workout.status != 'active') {
      throw const SessionNotEditableException('La sesión ya está cerrada');
    }
    return workout;
  }

  /// Series de la sesión en orden (incluidas las pendientes).
  Future<List<WorkoutSet>> _setsOfWorkout(String workoutId) async {
    final items = await (_db.select(
      _db.workoutExercises,
    )..where((t) => t.workoutId.equals(workoutId))).get();
    final itemIds = [for (final item in items) item.id];
    if (itemIds.isEmpty) return const [];

    return (_db.select(_db.workoutSets)
          ..where((t) => t.workoutExerciseId.isIn(itemIds))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();
  }

  /// Persiste el estado local del temporizador de descanso (RF-5 a RF-8 de la
  /// 002). No toca `updated_at` para no encolar sincronizaciones espurias.
  Future<void> saveRestTimer(
    String workoutId, {
    DateTime? endsAt,
    Duration? pausedRemaining,
  }) async {
    await (_db.update(
      _db.workouts,
    )..where((t) => t.id.equals(workoutId))).write(
      WorkoutsCompanion(
        restEndsAt: Value(endsAt),
        restPausedSeconds: Value(pausedRemaining?.inSeconds),
      ),
    );
  }

  Map<String, dynamic> _workoutPayload(Workout workout) => {
    'id': workout.id,
    'routine_id': workout.routineId,
    'name': workout.name,
    'status': workout.status,
    'started_at': workout.startedAt.toIso8601String(),
    'ended_at': workout.endedAt?.toIso8601String(),
    'notes': workout.notes,
    'client_updated_at': workout.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _exercisePayload(WorkoutExercise item) => {
    'id': item.id,
    'workout_id': item.workoutId,
    'exercise_id': item.exerciseId,
    'order_index': item.orderIndex,
    if (item.targetSets != null) 'target_sets': item.targetSets,
    if (item.targetReps != null) 'target_reps': item.targetReps,
    if (item.targetRir != null) 'target_rir': item.targetRir,
    if (item.suggestedWeightKg != null)
      'suggested_weight_kg': item.suggestedWeightKg,
  };

  Map<String, dynamic> _setPayload(WorkoutSet set) => {
    'id': set.id,
    'workout_exercise_id': set.workoutExerciseId,
    'routine_set_id': set.routineSetId,
    'order_index': set.orderIndex,
    'set_type': set.setType,
    'reps': set.reps,
    'weight_kg': set.weightKg,
    'rir': set.rir,
    'rest_seconds': set.restSeconds,
    'completed': set.completed,
  };

  Future<void> _enqueueRow(
    String operation,
    String table,
    Map<String, dynamic> payload,
  ) async {
    await enqueue?.call(operation, table, jsonEncode(payload));
  }
}

/// Junta las series de una sesión terminada para construir su [WorkoutSummary].
class _SummaryBuilder {
  _SummaryBuilder(this.workout);

  final Workout workout;
  final Map<String, _ExerciseSets> _exercises = {};

  void addSet({
    required String exerciseId,
    required String exerciseName,
    required int exerciseOrder,
    required WorkoutSet set,
  }) {
    _exercises
        .putIfAbsent(
          exerciseId,
          () => _ExerciseSets(exerciseName: exerciseName, order: exerciseOrder),
        )
        .add(set);
  }

  WorkoutSummary build() {
    final exercises = _exercises.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    var setCount = 0;
    var volumeKg = 0.0;
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        if (!set.completed) continue;
        setCount++;
        volumeKg += setVolumeKg(
          weightKg: set.weightKg,
          reps: set.reps,
          setType: set.setType,
          completed: true,
        );
      }
    }

    return WorkoutSummary(
      id: workout.id,
      routineId: workout.routineId,
      title: workout.name,
      startedAt: workout.startedAt,
      endedAt: workout.endedAt!,
      duration: workout.endedAt!.difference(workout.startedAt),
      setCount: setCount,
      volumeKg: volumeKg,
      highlights: [
        for (final exercise in exercises.take(3))
          ExerciseHighlight(
            name: exercise.exerciseName,
            weightKg: exercise.latest?.weightKg ?? 0,
            reps: exercise.latest?.reps ?? 0,
            rir: exercise.latest?.rir,
          ),
      ],
    );
  }
}

/// Series de un ejercicio dentro de una sesión, con la última serie
/// completada (sin calentamientos) para el destacado.
class _ExerciseSets {
  _ExerciseSets({required this.exerciseName, required this.order});

  final String exerciseName;
  final int order;
  final List<WorkoutSet> sets = [];
  WorkoutSet? latest;

  void add(WorkoutSet set) {
    sets.add(set);
    if (set.completed &&
        set.setType != 'warmup' &&
        (latest == null || set.orderIndex > latest!.orderIndex)) {
      latest = set;
    }
  }
}
