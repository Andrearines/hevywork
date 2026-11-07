import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/progression.dart';
import '../local/database.dart';
import 'workout_repository.dart';

/// Borrador de una serie planificada desde el editor (RF-1).
class RoutineSetDraft {
  /// Id de `routine_sets` si la serie ya existía en la rutina.
  final String? id;
  final String setType;
  final double weightKg;
  final int reps;
  final int rir;
  final int? restSeconds;

  const RoutineSetDraft({
    this.id,
    this.setType = 'normal',
    this.weightKg = 0,
    required this.reps,
    required this.rir,
    this.restSeconds,
  });
}

/// Borrador de ejercicio de rutina desde el editor (RF-1).
class RoutineExerciseDraft {
  /// Id de `routine_exercises` si el ejercicio ya existía en la rutina.
  final String? id;
  final String exerciseId;
  final List<RoutineSetDraft> sets;
  final bool autoProgress;

  const RoutineExerciseDraft({
    this.id,
    required this.exerciseId,
    required this.sets,
    this.autoProgress = true,
  });
}

/// Progresión sugerida de una serie planificada (RF-3/RF-4).
class SetProgressionSuggestion {
  final String routineSetId;
  final int orderIndex;
  final double currentWeightKg;
  final double suggestedWeightKg;

  const SetProgressionSuggestion({
    required this.routineSetId,
    required this.orderIndex,
    required this.currentWeightKg,
    required this.suggestedWeightKg,
  });
}

/// Sugerencia de progresión tras cerrar una sesión nacida de la rutina
/// (RF-3): el ejercicio y, serie a serie, el peso actual y el propuesto.
class ProgressionSuggestion {
  final String routineExerciseId;
  final String exerciseId;
  final String exerciseName;
  final List<SetProgressionSuggestion> sets;

  const ProgressionSuggestion({
    required this.routineExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });
}

/// Rutina sin ejercicios disponibles: no se puede iniciar (caso límite).
class EmptyRoutineException implements Exception {
  final String message;

  const EmptyRoutineException(this.message);

  @override
  String toString() => message;
}

/// Series planificadas agregadas por rutina: volumen total y rango de RIR
/// para las tarjetas (RF-20).
class RoutineSetsStats {
  final int totalSets;
  final int? minRir;
  final int? maxRir;

  const RoutineSetsStats({required this.totalSets, this.minRir, this.maxRir});
}

/// Plantillas de entrenamiento: creación, edición, borrado, instanciación
/// (RF-2) y progresión sugerida al cerrar la sesión (RF-3 y RF-4).
class RoutineRepository {
  final AppDatabase _db;
  final WorkoutRepository _workouts;

  /// Encola cada escritura local para subirla a Supabase (RF-11).
  final MutationEnqueuer? enqueue;

  RoutineRepository(this._db, this._workouts, {this.enqueue});

  Stream<List<Routine>> watchRoutines() =>
      (_db.select(_db.routines)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Número de ejercicios por rutina, para la lista (RF-1).
  Stream<Map<String, int>> watchExerciseCounts() {
    final countColumn = _db.routineExercises.id.count();
    final grouped = _db.selectOnly(_db.routineExercises)
      ..addColumns([_db.routineExercises.routineId, countColumn])
      ..groupBy([_db.routineExercises.routineId]);
    return grouped.watch().map(
          (rows) => {
            for (final row in rows)
              row.read(_db.routineExercises.routineId)!:
                  row.read(countColumn) ?? 0,
          },
        );
  }

  /// Series planificadas agregadas por rutina (volumen y rango de RIR),
  /// para las tarjetas de la lista (RF-20).
  Stream<Map<String, RoutineSetsStats>> watchRoutineSetsStats() {
    final query = _db.select(_db.routineSets).join([
      innerJoin(
        _db.routineExercises,
        _db.routineExercises.id.equalsExp(_db.routineSets.routineExerciseId),
      ),
    ]);
    return query.watch().map((rows) {
      final counts = <String, int>{};
      final mins = <String, int>{};
      final maxs = <String, int>{};
      for (final row in rows) {
        final set = row.readTable(_db.routineSets);
        final item = row.readTable(_db.routineExercises);
        counts[item.routineId] = (counts[item.routineId] ?? 0) + 1;
        final rir = set.rir;
        final min = mins[item.routineId];
        final max = maxs[item.routineId];
        mins[item.routineId] = (min == null || rir < min) ? rir : min;
        maxs[item.routineId] = (max == null || rir > max) ? rir : max;
      }
      return {
        for (final id in counts.keys)
          id: RoutineSetsStats(
            totalSets: counts[id]!,
            minRir: mins[id],
            maxRir: maxs[id],
          ),
      };
    });
  }

  /// Última sesión que nació de cada rutina, para «Último uso» (RF-20).
  Stream<Map<String, DateTime>> watchLastUsed() {
    final query = _db.select(_db.workouts)
      ..where((t) => t.routineId.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return query.watch().map((rows) {
      final last = <String, DateTime>{};
      for (final workout in rows) {
        last.putIfAbsent(workout.routineId!, () => workout.startedAt);
      }
      return last;
    });
  }

  /// Ejercicios de todas las rutinas con su fila de catálogo, para el
  /// desglose por músculos (RF-20).
  Stream<List<({RoutineExercise item, Exercise exercise})>>
      watchRoutineCatalog() {
    final query = _db.select(_db.routineExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.routineExercises.exerciseId),
      ),
    ])
      ..orderBy([OrderingTerm.asc(_db.routineExercises.orderIndex)]);
    return query.watch().map(
          (rows) => [
            for (final row in rows)
              (
                item: row.readTable(_db.routineExercises),
                exercise: row.readTable(_db.exercises),
              ),
          ],
        );
  }

  Future<Routine?> getRoutine(String routineId) =>
      (_db.select(_db.routines)..where((t) => t.id.equals(routineId)))
          .getSingleOrNull();

  /// Ejercicios de la rutina en orden. `exercise` es null si el ejercicio
  /// ya no está en el catálogo local (caso límite de la 004).
  Future<List<({RoutineExercise item, Exercise? exercise})>>
      routineExercises(String routineId) async {
    final query = _db.select(_db.routineExercises).join([
      leftOuterJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.routineExercises.exerciseId),
      ),
    ])
      ..where(_db.routineExercises.routineId.equals(routineId))
      ..orderBy([OrderingTerm.asc(_db.routineExercises.orderIndex)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          item: row.readTable(_db.routineExercises),
          exercise: row.readTableOrNull(_db.exercises),
        ),
    ];
  }

  /// Series planificadas de un ejercicio de rutina, en orden (RF-1).
  Future<List<RoutineSet>> routineSets(String routineExerciseId) =>
      (_db.select(_db.routineSets)
            ..where((t) => t.routineExerciseId.equals(routineExerciseId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Consulta todas las series de varios ejercicios de rutina en una sola
  /// llamada a la base (RF-1): reduce las N llamadas individuales a 1 sola.
  Future<List<RoutineSet>> routineSetsBatch(Iterable<String> routineExerciseIds) =>
      (_db.select(_db.routineSets)
            ..where((t) => t.routineExerciseId.isIn(routineExerciseIds.toList()))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Crea la rutina, sus ejercicios y sus series en una transacción y los
  /// encola por orden de cola (los padres antes que los hijos, RF-11).
  Future<Routine> createRoutine({
    required String name,
    String? description,
    String? category,
    String? level,
    String? goal,
    int? targetDays,
    required List<RoutineExerciseDraft> exercises,
  }) async {
    final now = DateTime.now();
    final profile = await (_db.select(_db.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();

    final routine = Routine(
      id: const Uuid().v4(),
      localUserId: profile.localUserId,
      name: name.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      category: _clean(category),
      level: _clean(level),
      goal: _clean(goal),
      targetDays: targetDays,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.routines).insert(routine);
    await _enqueueRow('upsert', 'routines', _routinePayload(routine));

    for (var i = 0; i < exercises.length; i++) {
      final item = _buildExercise(routine.id, exercises[i], i + 1, now);
      await _db.into(_db.routineExercises).insert(item);
      await _enqueueRow(
        'upsert',
        'routine_exercises',
        _routineExercisePayload(item),
      );
      for (var j = 0; j < exercises[i].sets.length; j++) {
        final set = _buildSet(item.id, exercises[i].sets[j], j + 1, now);
        await _db.into(_db.routineSets).insert(set);
        await _enqueueRow('upsert', 'routine_sets', _routineSetPayload(set));
      }
    }
    return routine;
  }

  /// Actualiza solo la metadata de planificación (spec 008, T-5) y la
  /// encola; los campos a null se limpian.
  Future<void> updateRoutineMetadata(
    String routineId, {
    String? category,
    String? level,
    String? goal,
    int? targetDays,
  }) async {
    final now = DateTime.now();
    final routine = await getRoutine(routineId);
    if (routine == null) return;

    final updated = routine.copyWith(
      category: Value(_clean(category)),
      level: Value(_clean(level)),
      goal: Value(_clean(goal)),
      targetDays: Value(targetDays),
      updatedAt: now,
    );
    await _db.update(_db.routines).replace(updated);
    await _enqueueRow('upsert', 'routines', _routinePayload(updated));
  }

  String? _clean(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// Guarda los cambios de la rutina: nombre, descripción y metadata de
  /// planificación, y los ejercicios y series reconciliados (borra los que
  /// ya no están, inserta los nuevos y actualiza los que cambiaron,
  /// reasignando `order_index` en orden).
  Future<void> updateRoutine({
    required String routineId,
    required String name,
    String? description,
    String? category,
    String? level,
    String? goal,
    int? targetDays,
    required List<RoutineExerciseDraft> exercises,
  }) async {
    final now = DateTime.now();
    final routine = await getRoutine(routineId);
    if (routine == null) return;

    final updatedRoutine = routine.copyWith(
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty ?? true ? null : description!.trim(),
      ),
      category: Value(_clean(category)),
      level: Value(_clean(level)),
      goal: Value(_clean(goal)),
      targetDays: Value(targetDays),
      updatedAt: now,
    );
    await _db.update(_db.routines).replace(updatedRoutine);
    await _enqueueRow('upsert', 'routines', _routinePayload(updatedRoutine));

    final existingRows = await routineExercises(routineId);
    final existingById = {
      for (final row in existingRows) row.item.id: row.item,
    };
    final wantedIds = {
      for (final draft in exercises)
        if (draft.id != null) draft.id!,
    };

    for (final row in existingRows) {
      if (!wantedIds.contains(row.item.id)) {
        await _deleteExerciseCascade(row.item.id);
      }
    }

    // Libera los order_index provisionales para no chocar con la UNIQUE
    // (routine_id, order_index) al reordenar.
    var tempIndex = -1;
    for (final row in existingRows) {
      if (!wantedIds.contains(row.item.id)) continue;
      await (_db.update(_db.routineExercises)
            ..where((t) => t.id.equals(row.item.id)))
          .write(RoutineExercisesCompanion(orderIndex: Value(tempIndex--)));
    }

    for (var i = 0; i < exercises.length; i++) {
      final draft = exercises[i];
      final orderIndex = i + 1;
      final existing = draft.id == null ? null : existingById[draft.id];
      if (existing != null) {
        final itemId = existing.id;
        if (_hasChanges(existing, draft, orderIndex)) {
          final updated = existing.copyWith(
            orderIndex: orderIndex,
            targetSets: Value(draft.sets.length),
            updatedAt: now,
          );
          await _db.update(_db.routineExercises).replace(updated);
          await _enqueueRow(
            'upsert',
            'routine_exercises',
            _routineExercisePayload(updated),
          );
        } else {
          await (_db.update(_db.routineExercises)
                ..where((t) => t.id.equals(existing.id)))
              .write(RoutineExercisesCompanion(orderIndex: Value(orderIndex)));
        }
        await _reconcileSets(itemId, draft.sets, now);
      } else {
        final item = _buildExercise(routineId, draft, orderIndex, now);
        await _db.into(_db.routineExercises).insert(item);
        await _enqueueRow(
          'upsert',
          'routine_exercises',
          _routineExercisePayload(item),
        );
        for (var j = 0; j < draft.sets.length; j++) {
          final set = _buildSet(item.id, draft.sets[j], j + 1, now);
          await _db.into(_db.routineSets).insert(set);
          await _enqueueRow('upsert', 'routine_sets', _routineSetPayload(set));
        }
      }
    }
  }

  /// Reconciliación de las series de un ejercicio (RF-1).
  Future<void> _reconcileSets(
    String routineExerciseId,
    List<RoutineSetDraft> drafts,
    DateTime now,
  ) async {
    final existing = await routineSets(routineExerciseId);
    final existingById = {for (final set in existing) set.id: set};
    final wantedIds = {
      for (final draft in drafts)
        if (draft.id != null) draft.id!,
    };

    for (final set in existing) {
      if (!wantedIds.contains(set.id)) {
        await (_db.delete(_db.routineSets)..where((t) => t.id.equals(set.id)))
            .go();
        await _enqueueRow('delete', 'routine_sets', {'id': set.id});
      }
    }

    var tempIndex = -1;
    for (final set in existing) {
      if (!wantedIds.contains(set.id)) continue;
      await (_db.update(_db.routineSets)..where((t) => t.id.equals(set.id)))
          .write(RoutineSetsCompanion(orderIndex: Value(tempIndex--)));
    }

    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final orderIndex = i + 1;
      final current = draft.id == null ? null : existingById[draft.id];
      if (current != null) {
        if (_setHasChanges(current, draft, orderIndex)) {
          final updated = current.copyWith(
            orderIndex: orderIndex,
            setType: draft.setType,
            weightKg: draft.weightKg,
            reps: draft.reps,
            rir: draft.rir,
            restSeconds: Value(draft.restSeconds),
            updatedAt: now,
          );
          await _db.update(_db.routineSets).replace(updated);
          await _enqueueRow(
            'upsert',
            'routine_sets',
            _routineSetPayload(updated),
          );
        } else {
          await (_db.update(_db.routineSets)
                ..where((t) => t.id.equals(current.id)))
              .write(RoutineSetsCompanion(orderIndex: Value(orderIndex)));
        }
      } else {
        final set = _buildSet(routineExerciseId, draft, orderIndex, now);
        await _db.into(_db.routineSets).insert(set);
        await _enqueueRow('upsert', 'routine_sets', _routineSetPayload(set));
      }
    }
  }

  /// Borra la rutina, sus ejercicios y sus series (cascada manual, RF-11).
  Future<void> deleteRoutine(String routineId) async {
    final items = await (_db.select(_db.routineExercises)
          ..where((t) => t.routineId.equals(routineId)))
        .get();
    for (final item in items) {
      await _deleteExerciseCascade(item.id);
    }
    await (_db.delete(_db.routines)..where((t) => t.id.equals(routineId))).go();
    await _enqueueRow('delete', 'routines', {'id': routineId});
  }

  /// Borra un ejercicio de rutina y sus series, encolando los borrados.
  Future<void> _deleteExerciseCascade(String routineExerciseId) async {
    final sets = await routineSets(routineExerciseId);
    for (final set in sets) {
      await (_db.delete(_db.routineSets)..where((t) => t.id.equals(set.id)))
          .go();
      await _enqueueRow('delete', 'routine_sets', {'id': set.id});
    }
    await (_db.delete(_db.routineExercises)
          ..where((t) => t.id.equals(routineExerciseId)))
        .go();
    await _enqueueRow('delete', 'routine_exercises', {
      'id': routineExerciseId,
    });
  }

  /// Inicia una sesión desde la rutina (RF-2): crea el workout con
  /// `routine_id`, clona los ejercicios y precarga sus series planificadas
  /// como pendientes (`completed = false`) con su descanso.
  /// Devuelve cuántos ejercicios de la rutina no estaban en el catálogo.
  Future<({Workout workout, int skippedExercises})> startWorkoutFromRoutine(
    String routineId,
  ) async {
    final routine = await getRoutine(routineId);
    if (routine == null) {
      throw const EmptyRoutineException('La rutina no existe');
    }

    final entries = await routineExercises(routineId);
    final availableCount =
        entries.where((row) => row.exercise != null).length;
    if (availableCount == 0) {
      throw const EmptyRoutineException(
        'La rutina no tiene ejercicios disponibles',
      );
    }

    final workout = await _workouts.startWorkout(
      routineId: routineId,
      name: routine.name,
    );

    var skipped = 0;
    for (final row in entries) {
      final item = row.item;
      if (row.exercise == null) {
        skipped++;
        continue;
      }
      final sets = await routineSets(item.id);
      // Use targetSets from routine if no series are available,
      // otherwise use the count from the planned sets.
      final targetSets = sets.isEmpty ? item.targetSets : sets.length;
      final planned = await _workouts.addExercise(
        workoutId: workout.id,
        exerciseId: item.exerciseId,
        targetSets: targetSets,
        targetReps: item.targetReps,
        targetRir: item.targetRir,
        suggestedWeightKg: item.suggestedWeightKg,
      );
      // Log each planned series as a pending set in the workout.
      // Si sets está vacío, creamos una serie default con los parámetros
      // de la rutina para que la sesión no quede vacía de series (RF-2).
      if (sets.isNotEmpty) {
        for (final set in sets) {
          await _workouts.logSet(
            workoutExerciseId: planned.id,
            weightKg: set.weightKg,
            reps: set.reps,
            rir: set.rir,
            setType: set.setType,
            restSeconds: set.restSeconds,
            routineSetId: set.id,
            completed: false,
          );
        }
      } else {
        // Fallback: log a default set using the routine's target parameters
        // so the session doesn't remain empty of series.
        await _workouts.logSet(
          workoutExerciseId: planned.id,
          weightKg: item.suggestedWeightKg ?? 0,
          reps: item.targetReps ?? 8,
          rir: item.targetRir ?? 0,
          setType: 'normal',
          restSeconds: 60,
          routineSetId: item.id,
          completed: false,
        );
      }
    }
    return (workout: workout, skippedExercises: skipped);
  }

  /// Sugerencias de progresión de una sesión nacida de la rutina (RF-3),
  /// evaluadas serie a serie: por cada ejercicio con `auto_progress` cuyas
  /// series de trabajo se cumplieron, la propuesta serie a serie.
  /// Se puede llamar en vivo (aviso al cumplir el objetivo) y al cerrar.
  Future<List<ProgressionSuggestion>> progressionSuggestions(
    String workoutId,
  ) async {
    final workout = await (_db.select(_db.workouts)
          ..where((t) => t.id.equals(workoutId)))
        .getSingleOrNull();
    if (workout == null || workout.routineId == null) return const [];

    final itemRows = await (_db.select(_db.workoutExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
      ),
    ])
          ..where(_db.workoutExercises.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm.asc(_db.workoutExercises.orderIndex)]))
        .get();

    final itemIds = [
      for (final row in itemRows) row.readTable(_db.workoutExercises).id,
    ];
    final sets = itemIds.isEmpty
        ? const <WorkoutSet>[]
        : await (_db.select(_db.workoutSets)
              ..where((t) => t.workoutExerciseId.isIn(itemIds))
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get();
    final setsByItem = <String, List<WorkoutSet>>{};
    for (final set in sets) {
      setsByItem.putIfAbsent(set.workoutExerciseId, () => []).add(set);
    }

    final plannedExercises = await (_db.select(_db.routineExercises)
          ..where((t) => t.routineId.equals(workout.routineId!)))
        .get();
    final plannedByExercise = <String, RoutineExercise>{
      for (final item in plannedExercises) item.exerciseId: item,
    };

    final suggestions = <ProgressionSuggestion>[];
    for (final row in itemRows) {
      final item = row.readTable(_db.workoutExercises);
      final exercise = row.readTable(_db.exercises);
      final plan = plannedByExercise[item.exerciseId];
      if (plan == null || !plan.autoProgress) continue;

      final plannedSets = await routineSets(plan.id);
      if (plannedSets.isEmpty) continue;

      final completed = [
        for (final set in setsByItem[item.id] ?? const <WorkoutSet>[])
          if (set.completed)
            (reps: set.reps, rir: set.rir ?? 0, setType: set.setType),
      ];
      final goalMet = plannedSetsGoalMet(
        planned: [
          for (final set in plannedSets)
            (
              id: set.id,
              orderIndex: set.orderIndex,
              setType: set.setType,
              weightKg: set.weightKg,
              reps: set.reps,
              rir: set.rir,
            ),
        ],
        completedSets: completed,
      );
      if (!goalMet) continue;

      final workSets = [
        for (final set in plannedSets)
          if (set.setType != 'warmup') set,
      ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      // El peso actual de la sugerencia es el que realmente se registró en la
      // serie de la sesión (RF-4), no el planificado: así lo que el usuario
      // tocó en vivo es lo que se propone subir.
      final completedWork = [
        for (final set in setsByItem[item.id] ?? const <WorkoutSet>[])
          if (set.completed && set.setType != 'warmup') set,
      ];
      final setSuggestions = workSets.indexed.map((entry) {
        final (index, set) = entry;
        final currentWeight = index < completedWork.length
            ? completedWork[index].weightKg
            : set.weightKg;
        return SetProgressionSuggestion(
          routineSetId: set.id,
          orderIndex: set.orderIndex,
          currentWeightKg: currentWeight,
          suggestedWeightKg: nextSuggestedWeight(currentWeight),
        );
      }).toList();
      if (setSuggestions.isEmpty) continue;

      suggestions.add(
        ProgressionSuggestion(
          routineExerciseId: plan.id,
          exerciseId: item.exerciseId,
          exerciseName: exercise.name,
          sets: setSuggestions,
        ),
      );
    }
    return suggestions;
  }

  /// Aplica el peso aprobado a una serie planificada (Aceptar o Sobrescribir,
  /// RF-4), redondeado a 0.001 kg, y la encola.
  Future<void> applyProgressedWeight(
    String routineSetId,
    double weightKg,
  ) async {
    final set = await (_db.select(_db.routineSets)
          ..where((t) => t.id.equals(routineSetId)))
        .getSingleOrNull();
    if (set == null) return;

    final now = DateTime.now();
    final updated = set.copyWith(
      weightKg: (weightKg * 1000).roundToDouble() / 1000,
      updatedAt: now,
    );
    await _db.update(_db.routineSets).replace(updated);
    await _enqueueRow('upsert', 'routine_sets', _routineSetPayload(updated));
  }

  /// Persiste en la rutina los valores reales de las series completadas de
  /// una sesión nacida de ella (RF-2/RF-4): cada serie planificada adopta el
  /// peso, las repeticiones y el RIR registrados en la serie que la originó.
  /// Así la próxima sesión precarga lo que de verdad se hizo.
  Future<void> persistSessionValues(String workoutId) async {
    final workout = await (_db.select(_db.workouts)
          ..where((t) => t.id.equals(workoutId)))
        .getSingleOrNull();
    if (workout == null || workout.routineId == null) return;

    final items = await (_db.select(_db.workoutExercises)
          ..where((t) => t.workoutId.equals(workoutId)))
        .get();
    final itemIds = [for (final item in items) item.id];
    if (itemIds.isEmpty) return;

    final sets = await (_db.select(_db.workoutSets)
          ..where((t) => t.workoutExerciseId.isIn(itemIds)))
        .get();

    final now = DateTime.now();
    for (final set in sets) {
      final routineSetId = set.routineSetId;
      if (!set.completed || routineSetId == null) continue;
      final current = await (_db.select(_db.routineSets)
            ..where((t) => t.id.equals(routineSetId)))
          .getSingleOrNull();
      if (current == null) continue;
      if (current.weightKg == set.weightKg &&
          current.reps == set.reps &&
          current.rir == (set.rir ?? 0)) {
        continue;
      }
      final updated = current.copyWith(
        weightKg: set.weightKg,
        reps: set.reps,
        rir: set.rir ?? 0,
        updatedAt: now,
      );
      await _db.update(_db.routineSets).replace(updated);
      await _enqueueRow('upsert', 'routine_sets', _routineSetPayload(updated));
    }
  }

  RoutineExercise _buildExercise(
    String routineId,
    RoutineExerciseDraft draft,
    int orderIndex,
    DateTime now,
  ) =>
      RoutineExercise(
        id: const Uuid().v4(),
        routineId: routineId,
        exerciseId: draft.exerciseId,
        orderIndex: orderIndex,
        targetSets: draft.sets.length,
        targetReps: null,
        targetRir: null,
        suggestedWeightKg: null,
        autoProgress: draft.autoProgress,
        createdAt: now,
        updatedAt: now,
      );

  RoutineSet _buildSet(
    String routineExerciseId,
    RoutineSetDraft draft,
    int orderIndex,
    DateTime now,
  ) =>
      RoutineSet(
        id: const Uuid().v4(),
        routineExerciseId: routineExerciseId,
        orderIndex: orderIndex,
        setType: draft.setType,
        weightKg: draft.weightKg,
        reps: draft.reps,
        rir: draft.rir,
        restSeconds: draft.restSeconds,
        createdAt: now,
        updatedAt: now,
      );

  bool _hasChanges(
    RoutineExercise current,
    RoutineExerciseDraft draft,
    int orderIndex,
  ) =>
      current.orderIndex != orderIndex ||
      current.targetSets != draft.sets.length ||
      current.autoProgress != draft.autoProgress;

  bool _setHasChanges(
    RoutineSet current,
    RoutineSetDraft draft,
    int orderIndex,
  ) =>
      current.orderIndex != orderIndex ||
      current.setType != draft.setType ||
      current.weightKg != draft.weightKg ||
      current.reps != draft.reps ||
      current.rir != draft.rir ||
      current.restSeconds != draft.restSeconds;

  Map<String, dynamic> _routinePayload(Routine routine) => {
        'id': routine.id,
        'name': routine.name,
        'description': routine.description,
        if (routine.category != null) 'category': routine.category,
        if (routine.level != null) 'level': routine.level,
        if (routine.goal != null) 'goal': routine.goal,
        if (routine.targetDays != null) 'target_days': routine.targetDays,
      };

  Map<String, dynamic> _routineExercisePayload(RoutineExercise item) => {
        'id': item.id,
        'routine_id': item.routineId,
        'exercise_id': item.exerciseId,
        'order_index': item.orderIndex,
        if (item.targetSets != null) 'target_sets': item.targetSets,
        if (item.targetReps != null) 'target_reps': item.targetReps,
        if (item.targetRir != null) 'target_rir': item.targetRir,
        if (item.suggestedWeightKg != null)
          'suggested_weight_kg': item.suggestedWeightKg,
        'auto_progress': item.autoProgress,
      };

  Map<String, dynamic> _routineSetPayload(RoutineSet set) => {
        'id': set.id,
        'routine_exercise_id': set.routineExerciseId,
        'order_index': set.orderIndex,
        'set_type': set.setType,
        'weight_kg': set.weightKg,
        'reps': set.reps,
        'rir': set.rir,
        if (set.restSeconds != null) 'rest_seconds': set.restSeconds,
      };

  Future<void> _enqueueRow(
    String operation,
    String table,
    Map<String, dynamic> payload,
  ) async {
    await enqueue?.call(operation, table, jsonEncode(payload));
  }
}
