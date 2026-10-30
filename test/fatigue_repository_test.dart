import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

void main() {
  late AppDatabase db;
  late FatigueRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FatigueRepository(db);
    await db.batch((b) => b.insertAll(db.exercises, [
      ExercisesCompanion.insert(
        id: 'ex-chest',
        name: 'Press de banca',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        muscleGroup: 'triceps',
      ),
      ExercisesCompanion.insert(
        id: 'ex-lats',
        name: 'Jalón al pecho',
        bodyPart: 'back',
        equipment: 'cable',
        target: 'lats',
        muscleGroup: 'biceps',
      ),
      ExercisesCompanion.insert(
        id: 'ex-hands',
        name: 'Agarre',
        bodyPart: 'hands',
        equipment: 'none',
        target: 'grip',
        muscleGroup: 'cardiovascular system',
      ),
      ExercisesCompanion.insert(
        id: 'ex-quads',
        name: 'Sentadilla',
        bodyPart: 'legs',
        equipment: 'barbell',
        target: 'quads',
        muscleGroup: 'quadriceps',
      ),
      ExercisesCompanion.insert(
        id: 'ex-bridge',
        name: 'Puente de glúteos',
        bodyPart: 'legs',
        equipment: 'barbell',
        target: 'glutes',
        muscleGroup: 'hamstrings',
      ),
    ]));
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 10, 9, 12);

  Future<String> profileId() async =>
      (await db.select(db.localProfiles).getSingle()).localUserId;

  Future<void> seedWorkout({
    required String workoutId,
    required String exerciseId,
    required DateTime endedAt,
    required double weightKg,
    required int reps,
    String setType = 'normal',
    bool completed = true,
  }) async {
    final workoutExerciseId = 'we-$workoutId';
    await db.into(db.workouts).insert(
          WorkoutsCompanion.insert(
            id: workoutId,
            localUserId: await profileId(),
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(endedAt),
          ),
        );
    await db.into(db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: workoutExerciseId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            orderIndex: 0,
          ),
        );
    await db.into(db.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: 'set-$workoutId',
            workoutExerciseId: workoutExerciseId,
            orderIndex: 0,
            setType: Value(setType),
            weightKg: Value(weightKg),
            reps: Value(reps),
            completed: Value(completed),
          ),
        );
  }

  Future<Map<String, double>> readCache() async {
    final rows = await db.select(db.muscleFatigue).get();
    return {for (final row in rows) row.muscle: row.fatigue};
  }

  test('el primario sale de `target`, no de `muscle_group` (amenda 2026-10-22)',
      () async {
    await seedWorkout(
      workoutId: 'w-chest',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 100,
      reps: 10,
    );
    await seedWorkout(
      workoutId: 'w-lats',
      exerciseId: 'ex-lats',
      endedAt: now,
      weightKg: 50,
      reps: 10,
      setType: 'drop',
    );

    await repo.recalculate(now: now);

    final cache = await readCache();
    expect(cache.keys, containsAll(['pectoralis_major', 'latissimus_dorsi']));
    expect(cache['pectoralis_major'], kHighValue);
    expect(cache['latissimus_dorsi'], kHighValue);
    // El `muscle_group` del press de banca es `triceps`, pero no es el
    // primario real: los tríceps no se marcan por ese press.
    expect(cache.containsKey('triceps'), isFalse);

    final rows = await db.select(db.muscleFatigue).get();
    final chest = rows.singleWhere((r) => r.muscle == 'pectoralis_major');
    expect(chest.raw, 1000);
    expect(chest.computedAt.year, 2026);
  });

  test('los glúteos se marcan aunque el dataset los liste como secundarios',
      () async {
    await seedWorkout(
      workoutId: 'w-bridge',
      exerciseId: 'ex-bridge',
      endedAt: now,
      weightKg: 60,
      reps: 12,
    );

    await repo.recalculate(now: now);

    final cache = await readCache();
    expect(cache['glutes'], kHighValue);
    expect(cache.containsKey('hamstrings'), isFalse);
  });

  test('warmup, series sin completar y objetivos sin zona no aportan', () async {
    await seedWorkout(
      workoutId: 'w-warm',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 100,
      reps: 10,
      setType: 'warmup',
    );
    await seedWorkout(
      workoutId: 'w-inc',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 150,
      reps: 10,
      completed: false,
    );
    await seedWorkout(
      workoutId: 'w-hands',
      exerciseId: 'ex-hands',
      endedAt: now,
      weightKg: 100,
      reps: 10,
    );

    await repo.recalculate(now: now);

    expect(await readCache(), isEmpty);
  });

  test('las series de peso corporal cuentan para el rol aunque su volumen '
      'sea 0 (RF-29)', () async {
    await seedWorkout(
      workoutId: 'w-bw',
      exerciseId: 'ex-bridge',
      endedAt: now,
      weightKg: 0,
      reps: 15,
    );

    await repo.recalculate(now: now);

    final cache = await readCache();
    expect(cache['glutes'], kHighValue);
  });

  test('el estado decae por rol: Alto → Óptimo → Recuperado (RF-25)', () async {
    Future<Map<String, double>> cacheAtAge(int days) async {
      await db.delete(db.workoutSets).go();
      await db.delete(db.workoutExercises).go();
      await db.delete(db.muscleFatigue).go();
      await db.delete(db.workouts).go();
      await seedWorkout(
        workoutId: 'w-age',
        exerciseId: 'ex-chest',
        endedAt: now.subtract(Duration(days: days)),
        weightKg: 100,
        reps: 10,
      );
      await repo.recalculate(now: now);
      return readCache();
    }

    expect((await cacheAtAge(0))['pectoralis_major'], kHighValue);
    expect((await cacheAtAge(1))['pectoralis_major'], kHighValue);
    expect((await cacheAtAge(2))['pectoralis_major'], kOptimalValue);
    expect((await cacheAtAge(3))['pectoralis_major'], kRecoveredValue);
  });

  test('las sesiones fuera de la ventana de 30 días no cuentan', () async {
    await seedWorkout(
      workoutId: 'w-31',
      exerciseId: 'ex-chest',
      endedAt: now.subtract(const Duration(days: 31)),
      weightKg: 100,
      reps: 10,
    );

    await repo.recalculate(now: now);

    expect(await readCache(), isEmpty);
  });

  test('recalcular reemplaza el cache (sin duplicados)', () async {
    await seedWorkout(
      workoutId: 'w-1',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 90,
      reps: 10,
    );
    await repo.recalculate(now: now);
    expect((await db.select(db.muscleFatigue).get()).length, 1);

    await seedWorkout(
      workoutId: 'w-2',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 110,
      reps: 10,
    );
    await repo.recalculate(now: now);

    final rows = await db.select(db.muscleFatigue).get();
    expect(rows, hasLength(1));
    expect(rows.single.raw, 2000);
  });

  test('sin sesiones el cache queda vacío y el stream lo refleja', () async {
    await repo.recalculate(now: now);
    expect(await readCache(), isEmpty);

    final stream = repo.watchFatigue();
    final first = await stream.first;
    expect(first, isEmpty);
  });

  test('watchFatigue emite la fatiga tras recalcular', () async {
    final events = <Map<String, double>>[];
    final subscription = repo.watchFatigue().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, isNotEmpty);
    expect(events.last, isEmpty);

    await seedWorkout(
      workoutId: 'w-quads',
      exerciseId: 'ex-quads',
      endedAt: now,
      weightKg: 80,
      reps: 8,
    );
    await repo.recalculate(now: now);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(events.last['quadriceps'], kHighValue);
    await subscription.cancel();
  });

  test('los secundarios permanecen en Óptimo aunque su volumen sea alto',
      () async {
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'ex-bench',
            name: 'Press inclinado',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["biceps"]'),
          ),
        );
    await seedWorkout(
      workoutId: 'w-bench',
      exerciseId: 'ex-bench',
      endedAt: now,
      weightKg: 100,
      reps: 10,
    );
    await seedWorkout(
      workoutId: 'w-chest2',
      exerciseId: 'ex-chest',
      endedAt: now,
      weightKg: 100,
      reps: 10,
    );

    await repo.recalculate(now: now);

    final cache = await readCache();
    expect(cache['pectoralis_major'], kHighValue);
    expect(cache['biceps'], kOptimalValue);
  });

  test('un secundario con volumen alto nunca sube a «Alto»', () async {
    await db.batch((b) => b.insertAll(db.exercises, [
      ExercisesCompanion.insert(
        id: 'ex-sec-pec',
        name: 'Press con bíceps',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        muscleGroup: 'triceps',
        secondaryMuscles: const Value('["biceps"]'),
      ),
      ExercisesCompanion.insert(
        id: 'ex-sec-lats',
        name: 'Jalón con bíceps',
        bodyPart: 'back',
        equipment: 'cable',
        target: 'lats',
        muscleGroup: 'biceps',
        secondaryMuscles: const Value('["biceps"]'),
      ),
      ExercisesCompanion.insert(
        id: 'ex-sec-tri',
        name: 'Extensión con bíceps',
        bodyPart: 'arms',
        equipment: 'cable',
        target: 'triceps',
        muscleGroup: 'shoulders',
        secondaryMuscles: const Value('["biceps"]'),
      ),
    ]));
    for (final id in ['ex-sec-pec', 'ex-sec-lats', 'ex-sec-tri']) {
      await seedWorkout(
        workoutId: 'w-$id',
        exerciseId: id,
        endedAt: now,
        weightKg: 100,
        reps: 10,
      );
    }

    await repo.recalculate(now: now);

    final cache = await readCache();
    expect(cache['biceps'], kOptimalValue);
    expect(cache['pectoralis_major'], kHighValue);
    expect(cache['latissimus_dorsi'], kHighValue);
  });

  test('un secundario se recupera antes que el primario (RF-25)', () async {
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'ex-bench-sec',
            name: 'Press con bíceps secundario',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["biceps"]'),
          ),
        );
    await seedWorkout(
      workoutId: 'w-sec',
      exerciseId: 'ex-bench-sec',
      endedAt: now.subtract(const Duration(days: 2)),
      weightKg: 100,
      reps: 10,
    );

    await repo.recalculate(now: now);

    final cache = await readCache();
    // A los 2 días el primario sigue en Óptimo, pero el secundario ya es
    // Recuperado (su ventana es de 2 días).
    expect(cache['pectoralis_major'], kOptimalValue);
    expect(cache['biceps'], kRecoveredValue);
  });

  test('weeklyZoneStats cuenta las series de peso corporal (RF-29)', () async {
    await seedWorkout(
      workoutId: 'w-bw-zone',
      exerciseId: 'ex-bridge',
      endedAt: now,
      weightKg: 0,
      reps: 15,
    );

    final rows = await repo.weeklyZoneStats(now: now);

    final glutes = rows.singleWhere((r) => r.muscle == 'glutes');
    expect(glutes.sets, 1);
    expect(glutes.weeklyVolume, 0);
  });
}
