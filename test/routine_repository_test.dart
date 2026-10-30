import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_payload.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;
  late RoutineRepository repo;
  late List<({String operation, String table, String payload})> enqueued;

  const benchDraft = RoutineExerciseDraft(
    exerciseId: 'bench-press',
    sets: [
      RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
      RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
      RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
    ],
  );
  const squatDraft = RoutineExerciseDraft(
    exerciseId: 'squat',
    autoProgress: false,
    sets: [
      RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
      RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
      RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
      RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
    ],
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];
    Future<void> enqueue(
      String operation,
      String table,
      String payload,
    ) async {
      enqueued.add((operation: operation, table: table, payload: payload));
    }
    workouts = WorkoutRepository(db, enqueue: enqueue);
    repo = RoutineRepository(db, workouts, enqueue: enqueue);
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'squat',
            name: 'Sentadilla',
            bodyPart: 'legs',
            equipment: 'barbell',
            target: 'quads',
            muscleGroup: 'legs',
          ),
        );
  });

  tearDown(() => db.close());

  Future<Routine> createRoutine() => repo.createRoutine(
        name: 'Tren superior',
        description: 'Fuerza y volumen',
        exercises: const [benchDraft, squatDraft],
      );

  Future<List<RoutineExercise>> routineItems(String routineId) =>
      (db.select(db.routineExercises)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  group('RF-1: crear rutina', () {
    test('guarda nombre, ejercicios y series y encola en orden', () async {
      final routine = await createRoutine();

      final stored = await (db.select(db.routines)
            ..where((t) => t.id.equals(routine.id)))
          .getSingle();
      expect(stored.name, 'Tren superior');
      expect(stored.description, 'Fuerza y volumen');

      final items = await routineItems(routine.id);
      expect(items, hasLength(2));
      expect(items[0].exerciseId, 'bench-press');
      expect(items[0].orderIndex, 1);
      expect(items[0].targetSets, 3);
      expect(items[0].autoProgress, isTrue);
      expect(items[1].exerciseId, 'squat');
      expect(items[1].autoProgress, isFalse);

      final benchSets = await repo.routineSets(items[0].id);
      expect(benchSets, hasLength(3));
      expect(benchSets[0].setType, 'normal');
      expect(benchSets[0].weightKg, 60);
      expect(benchSets[0].reps, 8);
      expect(benchSets[0].rir, 2);

      expect(enqueued, hasLength(10));
      expect(enqueued[0].operation, 'upsert');
      expect(enqueued[0].table, 'routines');
      expect(enqueued[1].table, 'routine_exercises');
      expect(enqueued[2].table, 'routine_sets');
      expect(enqueued[5].table, 'routine_exercises');
      expect(enqueued[6].table, 'routine_sets');
      expect(jsonDecode(enqueued[0].payload)['id'], routine.id);
      expect(jsonDecode(enqueued[1].payload)['order_index'], 1);
      expect(jsonDecode(enqueued[5].payload)['order_index'], 2);
      expect(jsonDecode(enqueued[1].payload)['auto_progress'], isTrue);
    });

    test('el payload de rutina es válido para el mapeo RF-13', () async {
      await createRoutine();

      final row = buildRemoteRow(
        table: 'routines',
        payloadJson: enqueued[0].payload,
        userId: 'user-1',
      );
      expect(row['user_id'], 'user-1');
      expect(row['name'], 'Tren superior');

      final setRow = buildRemoteRow(
        table: 'routine_sets',
        payloadJson: enqueued[2].payload,
        userId: 'user-1',
      );
      expect(setRow['user_id'], 'user-1');
      expect(setRow['weight_kg'], 60);
      expect(setRow['reps'], 8);
    });

    test('descripción en blanco se guarda como null', () async {
      final routine = await repo.createRoutine(
        name: 'Vacía',
        description: '   ',
        exercises: const [],
      );

      final stored = await (db.select(db.routines)
            ..where((t) => t.id.equals(routine.id)))
          .getSingle();
      expect(stored.description, isNull);
    });

    test('watchExerciseCounts cuenta los ejercicios de cada rutina', () async {
      final routine = await createRoutine();
      await repo.createRoutine(
        name: 'Solo prensa',
        exercises: const [benchDraft],
      );

      final counts = await repo.watchExerciseCounts().first;
      expect(counts[routine.id], 2);
    });
  });

  group('RF-1: editar rutina', () {
    test('renombra, reordena series y encola los cambios', () async {
      final routine = await createRoutine();
      final items = await routineItems(routine.id);
      final benchSets = await repo.routineSets(items[0].id);
      enqueued.clear();

      await repo.updateRoutine(
        routineId: routine.id,
        name: 'Tren completo',
        description: '',
        exercises: [
          RoutineExerciseDraft(
            id: items[1].id,
            exerciseId: 'squat',
            autoProgress: false,
            sets: const [
              RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
              RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
              RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
              RoutineSetDraft(reps: 6, rir: 1, weightKg: 80),
            ],
          ),
          RoutineExerciseDraft(
            id: items[0].id,
            exerciseId: 'bench-press',
            sets: [
              RoutineSetDraft(
                id: benchSets[0].id,
                reps: 8,
                rir: 2,
                weightKg: 60,
              ),
              RoutineSetDraft(
                id: benchSets[1].id,
                reps: 8,
                rir: 2,
                weightKg: 60,
              ),
              RoutineSetDraft(
                id: benchSets[2].id,
                reps: 8,
                rir: 2,
                weightKg: 65,
              ),
            ],
          ),
        ],
      );

      final stored = await (db.select(db.routines)
            ..where((t) => t.id.equals(routine.id)))
          .getSingle();
      expect(stored.name, 'Tren completo');

      final after = await routineItems(routine.id);
      expect(after, hasLength(2));
      expect(after[0].id, items[1].id);
      expect(after[0].orderIndex, 1);
      expect(after[1].id, items[0].id);
      expect(after[1].orderIndex, 2);

      final updatedSets = await repo.routineSets(items[0].id);
      expect(updatedSets.last.weightKg, 65);

      final setUpserts = enqueued
          .where((e) => e.operation == 'upsert' && e.table == 'routine_sets')
          .toList();
      expect(
        setUpserts
            .map((e) => (jsonDecode(e.payload)
                as Map<String, dynamic>)['weight_kg']),
        contains(65),
      );
    });

    test('quitar un ejercicio borra sus series y encola los deletes',
        () async {
      final routine = await createRoutine();
      final items = await routineItems(routine.id);
      final benchSets = await repo.routineSets(items[0].id);
      enqueued.clear();

      await repo.updateRoutine(
        routineId: routine.id,
        name: 'Tren superior',
        exercises: [
          RoutineExerciseDraft(
            id: items[0].id,
            exerciseId: 'bench-press',
            sets: [
              for (final set in benchSets)
                RoutineSetDraft(
                  id: set.id,
                  reps: set.reps,
                  rir: set.rir,
                  weightKg: set.weightKg,
                ),
            ],
          ),
        ],
      );

      final after = await routineItems(routine.id);
      expect(after, hasLength(1));
      expect(after.single.id, items[0].id);
      expect(await repo.routineSets(items[1].id), isEmpty);

      final deletes =
          enqueued.where((e) => e.operation == 'delete').toList();
      expect(deletes, hasLength(5));
      expect(deletes.first.table, 'routine_sets');
      expect(deletes.last.table, 'routine_exercises');
      expect(
        jsonDecode(deletes.last.payload)['id'],
        items[1].id,
      );
    });

    test('sin cambios no re-encola ejercicios ni series', () async {
      final routine = await createRoutine();
      final items = await routineItems(routine.id);
      enqueued.clear();

      final drafts = <RoutineExerciseDraft>[];
      for (final item in items) {
        final sets = await repo.routineSets(item.id);
        drafts.add(
          RoutineExerciseDraft(
            id: item.id,
            exerciseId: item.exerciseId,
            autoProgress: item.autoProgress,
            sets: [
              for (final set in sets)
                RoutineSetDraft(
                  id: set.id,
                  setType: set.setType,
                  weightKg: set.weightKg,
                  reps: set.reps,
                  rir: set.rir,
                  restSeconds: set.restSeconds,
                ),
            ],
          ),
        );
      }

      await repo.updateRoutine(
        routineId: routine.id,
        name: 'Tren superior',
        description: 'Fuerza y volumen',
        exercises: drafts,
      );

      expect(enqueued, hasLength(1));
      expect(enqueued.single.table, 'routines');
    });
  });

  group('RF-1: borrar rutina', () {
    test('borra hijos y rutina y encola los deletes', () async {
      final routine = await createRoutine();
      enqueued.clear();

      await repo.deleteRoutine(routine.id);

      expect(await db.select(db.routines).get(), isEmpty);
      expect(await db.select(db.routineExercises).get(), isEmpty);
      expect(await db.select(db.routineSets).get(), isEmpty);

      expect(enqueued, hasLength(10));
      expect(enqueued.where((e) => e.table == 'routine_sets'), hasLength(7));
      expect(enqueued.last.operation, 'delete');
      expect(enqueued.last.table, 'routines');
      expect(jsonDecode(enqueued.last.payload)['id'], routine.id);
    });
  });

  group('RF-2: instanciar la rutina', () {
    test('precarga las series planificadas como pendientes', () async {
      final routine = await createRoutine();
      enqueued.clear();

      final result = await repo.startWorkoutFromRoutine(routine.id);

      expect(result.workout.routineId, routine.id);
      expect(result.workout.name, 'Tren superior');
      expect(result.skippedExercises, 0);

      final items = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(result.workout.id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      expect(items, hasLength(2));
      expect(items[0].exerciseId, 'bench-press');
      expect(items[0].targetSets, 3);

      final sets = await (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(items[0].id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      expect(sets, hasLength(3));
      expect(sets.every((s) => s.completed), isFalse);
      expect(sets[0].weightKg, 60);
      expect(sets[0].reps, 8);
      expect(sets[0].rir, 2);

      // Cada serie pendiente conserva el vínculo con su serie planificada
      // (RF-2/RF-4): sirve para persistir en la rutina lo hecho en la sesión.
      final planned = await routineItems(routine.id);
      final plannedSets = await (db.select(db.routineSets)
            ..where((t) => t.routineExerciseId.equals(planned[0].id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      expect(sets[0].routineSetId, plannedSets[0].id);
      expect(sets[1].routineSetId, plannedSets[1].id);
      expect(sets[2].routineSetId, plannedSets[2].id);

      final workoutRow = buildRemoteRow(
        table: 'workouts',
        payloadJson: enqueued.first.payload,
        userId: 'user-1',
      );
      expect(workoutRow['routine_id'], routine.id);
    });

    test('con una sesión activa, la abandona (RF-19)', () async {
      final routine = await createRoutine();
      final previous = await workouts.startWorkout();
      await workouts.addExercise(
        workoutId: previous.id,
        exerciseId: 'bench-press',
      );
      enqueued.clear();

      final result = await repo.startWorkoutFromRoutine(routine.id);

      final stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(previous.id)))
          .getSingle();
      expect(stored.status, 'abandoned');

      final workoutPayloads =
          enqueued.where((e) => e.table == 'workouts').toList();
      expect(workoutPayloads, hasLength(2));
      expect(jsonDecode(workoutPayloads[0].payload)['status'], 'abandoned');
      expect(jsonDecode(workoutPayloads[1].payload)['status'], 'active');
      expect(result.workout.id, isNot(previous.id));
    });

    test('una rutina sin ejercicios no se puede iniciar', () async {
      final routine = await repo.createRoutine(
        name: 'Vacía',
        exercises: const [],
      );

      await expectLater(
        repo.startWorkoutFromRoutine(routine.id),
        throwsA(isA<EmptyRoutineException>()),
      );
    });

    test('los ejercicios fuera del catálogo se omiten con aviso', () async {
      final routine = await repo.createRoutine(
        name: 'Con fantasma',
        exercises: const [],
      );
      await db.batch((batch) {
        batch.insertAll(db.routineExercises, [
          RoutineExercisesCompanion.insert(
            id: 're-fantasma',
            routineId: routine.id,
            exerciseId: 'no-existe',
            orderIndex: 1,
            targetSets: const Value(3),
            targetReps: const Value(8),
            targetRir: const Value(2),
            suggestedWeightKg: const Value(50),
          ),
          RoutineExercisesCompanion.insert(
            id: 're-real',
            routineId: routine.id,
            exerciseId: 'bench-press',
            orderIndex: 2,
            targetSets: const Value(3),
            targetReps: const Value(8),
            targetRir: const Value(2),
            suggestedWeightKg: const Value(60),
          ),
        ]);
      });

      final result = await repo.startWorkoutFromRoutine(routine.id);

      expect(result.skippedExercises, 1);
      final items = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(result.workout.id)))
          .get();
      expect(items, hasLength(1));
      expect(items.single.exerciseId, 'bench-press');
    });
  });

  group('RF-3/RF-4: progresión serie a serie', () {
    Future<String> startAndLog({
      required int setsBench,
      required int repsBench,
      required int rirBench,
    }) async {
      final routine = await createRoutine();
      enqueued.clear();
      final workout = await repo.startWorkoutFromRoutine(routine.id);
      final items = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.workout.id)))
          .get();
      final bench = items.firstWhere((item) => item.exerciseId == 'bench-press');
      for (var i = 0; i < setsBench; i++) {
        await workouts.logSet(
          workoutExerciseId: bench.id,
          weightKg: 60,
          reps: repsBench,
          rir: rirBench,
        );
      }
      return workout.workout.id;
    }

    test('sugiere +2.5 kg serie a serie si el ejercicio cumple', () async {
      final workoutId = await startAndLog(
        setsBench: 3,
        repsBench: 8,
        rirBench: 2,
      );

      final suggestions = await repo.progressionSuggestions(workoutId);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.exerciseName, 'Press de banca');
      expect(suggestions.single.sets, hasLength(3));
      for (final set in suggestions.single.sets) {
        expect(set.currentWeightKg, 60);
        expect(set.suggestedWeightKg, 62.5);
      }
    });

    test('no sugiere si faltan series completadas', () async {
      final workoutId = await startAndLog(
        setsBench: 2,
        repsBench: 8,
        rirBench: 2,
      );

      final suggestions = await repo.progressionSuggestions(workoutId);
      expect(suggestions, isEmpty);
    });

    test('no sugiere si las series bajan de repeticiones', () async {
      final workoutId = await startAndLog(
        setsBench: 3,
        repsBench: 6,
        rirBench: 2,
      );

      final suggestions = await repo.progressionSuggestions(workoutId);
      expect(suggestions, isEmpty);
    });

    test('no sugiere si el RIR se queda corto (por encima del objetivo)',
        () async {
      final workoutId = await startAndLog(
        setsBench: 3,
        repsBench: 8,
        rirBench: 4,
      );

      final suggestions = await repo.progressionSuggestions(workoutId);
      expect(suggestions, isEmpty);
    });

    test('una sesión libre no genera sugerencias', () async {
      final workout = await workouts.startWorkout();
      await workouts.addExercise(
        workoutId: workout.id,
        exerciseId: 'bench-press',
      );

      final suggestions = await repo.progressionSuggestions(workout.id);
      expect(suggestions, isEmpty);
    });

    test('applyProgressedWeight escribe el peso en la serie y la encola',
        () async {
      final routine = await createRoutine();
      final items = await routineItems(routine.id);
      final bench = items.firstWhere((e) => e.exerciseId == 'bench-press');
      final sets = await repo.routineSets(bench.id);
      enqueued.clear();

      await repo.applyProgressedWeight(sets.first.id, 62.5);

      final updated = await (db.select(db.routineSets)
            ..where((t) => t.id.equals(sets.first.id)))
          .getSingle();
      expect(updated.weightKg, 62.5);

      expect(enqueued, hasLength(1));
      expect(enqueued.single.table, 'routine_sets');
      final payload =
          jsonDecode(enqueued.single.payload) as Map<String, dynamic>;
      expect(payload['id'], sets.first.id);
      expect(payload['weight_kg'], 62.5);
    });

    test('persistir la sesión adopta en la rutina lo registrado y lo encola',
        () async {
      final routine = await createRoutine();
      final items = await routineItems(routine.id);
      final bench = items.firstWhere((e) => e.exerciseId == 'bench-press');
      enqueued.clear();

      final started = await repo.startWorkoutFromRoutine(routine.id);
      final wItems = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(started.workout.id)))
          .get();
      final wBench = wItems.firstWhere((e) => e.exerciseId == 'bench-press');
      final wSets = await (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(wBench.id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      expect(wSets, hasLength(3));

      // Se confirman con un peso/reps/RIR reales distintos del plan.
      await workouts.updateSet(
        setId: wSets[0].id,
        weightKg: 62.5,
        reps: 9,
        rir: 1,
      );
      await workouts.updateSet(
        setId: wSets[1].id,
        weightKg: 62.5,
        reps: 9,
        rir: 1,
      );
      await workouts.updateSet(
        setId: wSets[2].id,
        weightKg: 65,
        reps: 8,
        rir: 1,
      );

      await repo.persistSessionValues(started.workout.id);

      final updated = await repo.routineSets(bench.id);
      expect(updated[0].weightKg, 62.5);
      expect(updated[0].reps, 9);
      expect(updated[0].rir, 1);
      expect(updated[2].weightKg, 65);
      expect(updated[2].reps, 8);

      // Solo se encolan las series que cambiaron: las 3 del banco.
      expect(enqueued.where((e) => e.table == 'routine_sets'), hasLength(3));
    });

    test('persistir la sesión ignora las series pendientes sin confirmar',
        () async {
      final routine = await createRoutine();
      final started = await repo.startWorkoutFromRoutine(routine.id);
      enqueued.clear();

      await repo.persistSessionValues(started.workout.id);

      final items = await routineItems(routine.id);
      final bench = items.firstWhere((e) => e.exerciseId == 'bench-press');
      final planned = await repo.routineSets(bench.id);
      expect(planned.every((set) => set.weightKg == 60), isTrue);
      expect(planned.every((set) => set.reps == 8), isTrue);
      expect(enqueued.where((e) => e.table == 'routine_sets'), isEmpty);
    });
  });

  group('T-5: metadata de planificación', () {
    test('createRoutine guarda la metadata y la encola en el payload',
        () async {
      final routine = await repo.createRoutine(
        name: 'Push / Pull / Legs',
        description: 'Seis días de empuje y tirón',
        category: 'PPL',
        level: 'Intermedio',
        goal: 'Fuerza',
        targetDays: 6,
        exercises: const [benchDraft],
      );

      final stored = await repo.getRoutine(routine.id);
      expect(stored!.category, 'PPL');
      expect(stored.level, 'Intermedio');
      expect(stored.goal, 'Fuerza');
      expect(stored.targetDays, 6);

      final payload = jsonDecode(enqueued[0].payload) as Map<String, dynamic>;
      expect(enqueued[0].table, 'routines');
      expect(payload['category'], 'PPL');
      expect(payload['level'], 'Intermedio');
      expect(payload['goal'], 'Fuerza');
      expect(payload['target_days'], 6);

      // El payload mapea a la fila que Postgres espera (RF-13).
      final row = buildRemoteRow(
        table: 'routines',
        payloadJson: enqueued[0].payload,
        userId: 'user-1',
      );
      expect(row['user_id'], 'user-1');
      expect(row['category'], 'PPL');
      expect(row['level'], 'Intermedio');
      expect(row['goal'], 'Fuerza');
      expect(row['target_days'], 6);
    });

    test('una rutina sin metadata no muestra huecos y se puede rellenar',
        () async {
      final routine = await createRoutine();

      final stored = await repo.getRoutine(routine.id);
      expect(stored!.category, isNull);
      expect(stored.level, isNull);
      expect(stored.goal, isNull);
      expect(stored.targetDays, isNull);

      // Metadatos en blanco: se guardan como null, no como vacío.
      await repo.updateRoutineMetadata(routine.id, level: '   ');
      await repo.updateRoutineMetadata(
        routine.id,
        category: 'Torso-Pierna',
        targetDays: 4,
      );

      final updated = await repo.getRoutine(routine.id);
      expect(updated!.category, 'Torso-Pierna');
      expect(updated.targetDays, 4);
      expect(updated.level, isNull);
      expect(updated.name, 'Tren superior');

      final payloads = enqueued
          .where((row) =>
              row.table == 'routines' &&
              jsonDecode(row.payload)['id'] == routine.id)
          .toList();
      final last = jsonDecode(payloads.last.payload) as Map<String, dynamic>;
      expect(last['category'], 'Torso-Pierna');
      expect(last['target_days'], 4);
      expect(last.containsKey('level'), isFalse);
      expect(last.containsKey('category'), isTrue);

      final row = buildRemoteRow(
        table: 'routines',
        payloadJson: payloads.last.payload,
        userId: 'user-1',
      );
      expect(row['category'], 'Torso-Pierna');
      expect(row['target_days'], 4);
      expect(row.containsKey('level'), isFalse);
    });
  });
}
