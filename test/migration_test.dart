import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';

const _legacyTables = [
  '''
  CREATE TABLE "exercises" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "muscle_group" TEXT NOT NULL,
    "secondary_muscles" TEXT NOT NULL,
    "equipment" TEXT NOT NULL,
    "asset_image" TEXT NULL,
    "asset_gif" TEXT NULL,
    "body_part" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "exercise_instructions" (
    "exercise_id" TEXT NOT NULL REFERENCES exercises (id),
    "locale" TEXT NOT NULL,
    "step" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    PRIMARY KEY ("exercise_id", "locale", "step")
  )
  ''',
  '''
  CREATE TABLE "workouts" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "started_at" INTEGER NOT NULL,
    "ended_at" INTEGER NULL,
    "notes" TEXT NULL,
    "client_updated_at" INTEGER NOT NULL,
    "server_updated_at" INTEGER NULL,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "workout_exercises" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "workout_id" TEXT NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    "exercise_id" TEXT NOT NULL,
    "order_index" INTEGER NOT NULL,
    "notes" TEXT NULL,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    "server_updated_at" INTEGER NULL,
    "rest_timer_seconds" INTEGER NULL,
    "rest_timer_running" INTEGER NULL,
    "rest_timer_started_at" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "workout_sets" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "workout_exercise_id" TEXT NOT NULL REFERENCES workout_exercises (id) ON DELETE CASCADE,
    "order_index" INTEGER NOT NULL,
    "set_type" TEXT NOT NULL DEFAULT 'normal',
    "reps" INTEGER NOT NULL,
    "weight_kg" REAL NULL,
    "rir" INTEGER NULL,
    "completed" INTEGER NOT NULL DEFAULT 1,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    "server_updated_at" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "local_profiles" (
    "id" INTEGER NOT NULL CHECK(id = 1),
    "local_user_id" TEXT NOT NULL,
    "auth_user_id" TEXT NULL,
    "display_name" TEXT NULL,
    "unit_system" TEXT NOT NULL DEFAULT 'metric',
    "catalog_version" INTEGER NOT NULL DEFAULT 0,
    "last_active_workout_id" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "sync_queue" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "table_name" TEXT NOT NULL,
    "record_id" TEXT NOT NULL,
    "op" TEXT NOT NULL,
    "payload" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" INTEGER NOT NULL DEFAULT 0,
    "dead_letter" INTEGER NOT NULL DEFAULT 0,
    UNIQUE ("table_name", "record_id", "op")
  )
  ''',
  '''
  CREATE VIRTUAL TABLE "exercises_fts" USING fts5(
    id, name, body_part, target, muscle_group, equipment,
    content=exercises
  )
  ''',
  '''
  CREATE TRIGGER exercises_ai AFTER INSERT ON exercises BEGIN
    INSERT INTO exercises_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
  END
  ''',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late File file;

  setUp(() {
    file = File(
      '${Directory.systemTemp.path}/hevywork_migration_'
      '${DateTime.now().microsecondsSinceEpoch}_$pid.sqlite',
    );
  });

  tearDown(() {
    if (file.existsSync()) file.deleteSync();
  });

  Future<void> createLegacyFile() async {
    final legacy = AppDatabase(NativeDatabase(file, enableMigrations: false));
    for (final statement in _legacyTables) {
      await legacy.customStatement(statement);
    }
    await legacy.customStatement(
      "INSERT INTO exercises VALUES "
      "('0001', 'Press de banca con barra', 'pectorals', 'pecho', '[]', "
      "'barbell', 'images/0001.jpg', 'videos/0001.gif', 'chest')",
    );
    await legacy.customStatement(
      "INSERT INTO exercise_instructions VALUES "
      "('0001', 'es', 1, 'Aprieta la barra sobre el pecho')",
    );
    await legacy.customStatement(
      "INSERT INTO local_profiles (local_user_id) "
      "VALUES ('perfil-antiguo')",
    );
    await legacy.customStatement('PRAGMA user_version = 2');
    await legacy.close();
  }

  test(
    'una base local con esquema antiguo se reconstruye al abrirla',
    () async {
      await createLegacyFile();

      final db = AppDatabase(NativeDatabase(file));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 20);

      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('exercises')")
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['image_path', 'gif_path', 'attribution', 'rest_seconds']),
      );

      final steps = await db
          .customSelect(
            'SELECT language, step_number, instruction FROM exercise_instructions',
          )
          .get();
      expect(steps, isEmpty);

      final exercises = await db.select(db.exercises).get();
      expect(exercises, isEmpty);

      final profiles = await db.select(db.localProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.single.localUserId, isNot('perfil-antiguo'));

      final leftovers = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name IN "
            "('exercises_fts', 'exercises_ai')",
          )
          .get();
      expect(leftovers, isEmpty);

      await db.close();
    },
  );

  test('una base con el esquema actual solo sube de versión', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
          ),
        );
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final exercises = await reopened.select(reopened.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.imagePath, isNull);

    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));

    await reopened.close();
  });

  test('una base v3 sube a v4 con el descanso y sin perder datos', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
          ),
        );
    // Simula una base creada antes de la spec 002 (v3).
    await db.customStatement('ALTER TABLE exercises DROP COLUMN rest_seconds');
    await db.customStatement('ALTER TABLE workouts DROP COLUMN rest_ends_at');
    await db.customStatement(
      'ALTER TABLE workouts DROP COLUMN rest_paused_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN last_active_workout_id',
    );
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final exercise = await reopened.select(reopened.exercises).getSingle();
    expect(exercise.id, '0001');
    expect(exercise.restSeconds, 90);

    final workoutColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('workouts')")
        .get();
    expect(
      workoutColumns.map((row) => row.read<String>('name')),
      containsAll(['rest_ends_at', 'rest_paused_seconds']),
    );

    final profileColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      profileColumns.map((row) => row.read<String>('name')),
      contains('last_active_workout_id'),
    );

    // El CHECK del rango (15–300) se aplica también tras la migración.
    await expectLater(
      reopened
          .into(reopened.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: '0002',
              name: 'Sentadilla',
              bodyPart: 'legs',
              equipment: 'barbell',
              target: 'quads',
              muscleGroup: 'piernas',
              restSeconds: const Value(400),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    await reopened.close();
  });

  test(
    'una base v4 sube a v5 con el marcador de reanudación sin perder datos',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db
          .into(db.workouts)
          .insertReturning(
            WorkoutsCompanion.insert(
              id: 'w-0001',
              localUserId: 'perfil-1',
              name: const Value('Tren inferior'),
              startedAt: DateTime(2026, 10, 5),
              status: const Value('active'),
            ),
          );
      // Simula una base creada sin el marcador del RF-9 (v4).
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN last_active_workout_id',
      );
      await db.customStatement('DROP TABLE routine_sets');
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
      );
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
      );
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
      );
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 20);

      final profiles = await reopened.select(reopened.localProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.single.lastActiveWorkoutId, isNull);

      final stored = await reopened.select(reopened.workouts).getSingleOrNull();
      expect(stored!.id, 'w-0001');
      expect(stored.status, 'active');

      await reopened.close();
    },
  );

  test('una base v5 sube a v6 creando rutinas y sus ejercicios', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement('DROP TABLE routine_exercises');
    await db.customStatement('DROP TABLE routines');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final routineColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routines')")
        .get();
    expect(
      routineColumns.map((row) => row.read<String>('name')),
      containsAll(['id', 'local_user_id', 'name', 'description']),
    );

    final exerciseColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routine_exercises')")
        .get();
    expect(
      exerciseColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'routine_id',
        'exercise_id',
        'order_index',
        'target_sets',
        'target_reps',
        'target_rir',
        'suggested_weight_kg',
        'auto_progress',
      ]),
    );

    await reopened
        .into(reopened.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'r-0001',
            localUserId: 'perfil-1',
            name: 'Tren superior',
          ),
        );

    await reopened.close();
  });

  test('una base v6 sube a v10 creando metas y el registro diario', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE body_metrics');
    await db.customStatement('DROP TABLE goals');
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 6');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final goalColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('goals')")
        .get();
    expect(
      goalColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'local_user_id',
        'type',
        'target_value',
        'deadline',
        'period',
        'metric_ref',
        'status',
        'current_value',
        'baseline_value',
      ]),
    );

    final metricColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('body_metrics')")
        .get();
    expect(
      metricColumns.map((row) => row.read<String>('name')),
      containsAll([
        'local_user_id',
        'date',
        'weight_kg',
        'measures_json',
        'notes',
      ]),
    );

    await reopened
        .into(reopened.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'g-0001',
            localUserId: 'perfil-1',
            type: 'strength',
            targetValue: 80,
          ),
        );
    await reopened
        .into(reopened.bodyMetrics)
        .insert(
          BodyMetricsCompanion.insert(
            localUserId: 'perfil-1',
            date: DateTime(2026, 10, 1),
          ),
        );

    await reopened.close();
  });

  test('una base v9 consolida el peso previo en body_metrics', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE body_metrics');
    await db.customStatement(
      'CREATE TABLE body_weight ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'local_user_id TEXT NOT NULL, '
      'weight_kg REAL NOT NULL, '
      'measured_at INTEGER NOT NULL, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)',
    );
    // El mismo formato que guarda drift: DateTime como epoch en segundos.
    final measured = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
    final stamp = DateTime(2026, 10, 1, 7).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      "INSERT INTO body_weight VALUES "
      "('bw-0001', 'perfil-1', 82, $measured, $stamp, $stamp)",
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 9');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final rows = await reopened.select(reopened.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.localUserId, 'perfil-1');
    expect(rows.single.weightKg, 82);
    expect(rows.single.measuresJson, isNull);
    expect(rows.single.date.year, 2026);
    expect(rows.single.date.month, 10);
    expect(rows.single.date.day, 1);

    final leftover = await reopened
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'body_weight'",
        )
        .get();
    expect(leftover, isEmpty);

    await reopened.close();
  });

  test('una base v10 crea el cache local de fatiga (spec 007)', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE muscle_fatigue');
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 10');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('muscle_fatigue')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['local_user_id', 'muscle', 'fatigue', 'raw', 'computed_at']),
    );

    await reopened
        .into(reopened.muscleFatigue)
        .insert(
          MuscleFatigueCompanion.insert(
            localUserId: 'perfil-1',
            muscle: 'pectoralis_major',
            fatigue: 1.0,
            raw: 1000,
            computedAt: DateTime(2026, 10, 9),
          ),
        );

    await reopened.close();
  });

  test('una base v7 sube a v8 creando las series planificadas', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final setColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routine_sets')")
        .get();
    expect(
      setColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'routine_exercise_id',
        'order_index',
        'set_type',
        'weight_kg',
        'reps',
        'rir',
        'rest_seconds',
      ]),
    );

    final workoutSetColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('workout_sets')")
        .get();
    expect(
      workoutSetColumns.map((row) => row.read<String>('name')),
      containsAll(['rest_seconds', 'routine_set_id']),
    );

    await reopened.close();
  });

  test(
    'una base v8 sube a v9 añadiendo el vínculo de serie de rutina',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
      );
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
      );
      await db.customStatement('PRAGMA user_version = 8');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 20);

      final columns = await reopened
          .customSelect("SELECT name FROM pragma_table_info('workout_sets')")
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('routine_set_id'),
      );

      await reopened.close();
    },
  );

  test('una base v11 sube a v13 con la preferencia RIR/RPE', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('prefer_rpe'),
    );

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.preferRpe, isFalse);

    await reopened.close();
  });

  test('una base v11 sube a v13 con la metadata de la rutina', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    for (final column in ['category', 'level', 'goal', 'target_days']) {
      await db.customStatement('ALTER TABLE routines DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routines')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['category', 'level', 'goal', 'target_days']),
    );

    // Una rutina previa (sin metadata) se lee completa, con los campos a
    // null y sin huecos.
    await reopened
        .into(reopened.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'rutina-sin-metadata',
            localUserId: 'usuario',
            name: 'Vieja',
          ),
        );
    final rows = await reopened.select(reopened.routines).get();
    expect(rows.single.name, 'Vieja');
    expect(rows.single.category, isNull);
    expect(rows.single.level, isNull);
    expect(rows.single.goal, isNull);
    expect(rows.single.targetDays, isNull);

    await reopened.close();
  });

  test('una base v13 sube a v14 con la tabla de fotos de progreso', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE progress_photos');
    await db.customStatement('PRAGMA user_version = 13');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    await reopened
        .into(reopened.progressPhotos)
        .insert(
          ProgressPhotosCompanion.insert(
            id: 'foto-1',
            localUserId: 'usuario',
            date: DateTime(2026, 10, 18),
            view: 'front',
            path: '/tmp/foto-1.jpg',
            storagePath: 'usuario/foto-1.jpg',
          ),
        );
    final rows = await reopened.select(reopened.progressPhotos).get();
    expect(rows.single.uploadStatus, 'pending');

    await reopened.close();
  });

  test('una base v14 sube a v15 con composición y datos del atleta', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE body_metrics DROP COLUMN body_fat_pct',
    );
    await db.customStatement(
      'ALTER TABLE body_metrics DROP COLUMN lean_mass_kg',
    );
    await db.customStatement('ALTER TABLE local_profiles DROP COLUMN sex');
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN height_cm',
    );
    await db.customStatement('PRAGMA user_version = 14');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final metricColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('body_metrics')")
        .get();
    expect(
      metricColumns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['body_fat_pct', 'lean_mass_kg']),
    );

    final profileColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      profileColumns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['sex', 'height_cm']),
    );

    // Un registro previo se lee sin huecos y admite composición.
    await reopened
        .into(reopened.bodyMetrics)
        .insert(
          BodyMetricsCompanion.insert(
            localUserId: 'usuario',
            date: DateTime(2026, 10, 5),
            bodyFatPct: const Value(18.5),
            leanMassKg: const Value(65.2),
          ),
        );
    final rows = await reopened.select(reopened.bodyMetrics).get();
    expect(rows.single.bodyFatPct, 18.5);
    expect(rows.single.leanMassKg, 65.2);

    await reopened.close();
  });

  test(
    'una base v15 sube a v16 con el cache de plantillas (spec 010)',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE IF EXISTS template_sets');
      await db.customStatement('DROP TABLE IF EXISTS template_exercises');
      await db.customStatement('DROP TABLE IF EXISTS template_days');
      await db.customStatement('DROP TABLE IF EXISTS templates');
      await db.customStatement('PRAGMA user_version = 15');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 20);

      final tables = await reopened
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name LIKE 'template%'",
          )
          .get();
      expect(
        tables.map((row) => row.read<String>('name')).toSet(),
        containsAll([
          'templates',
          'template_days',
          'template_exercises',
          'template_sets',
        ]),
      );

      await reopened.close();
    },
  );

  test('una migración interrumpida (columna creada, versión atrasada) se '
      'repara sin romper la apertura', () async {
    // Escenario real: la app se cerró a mitad de un `onUpgrade` y la base
    // quedó con el esquema ya avanzado pero el `user_version` atrasado. Sin
    // la guarda idempotente, el `ALTER TABLE` fallaba con «duplicate column
    // name: prefer_rpe» y la app no arrancaba.
    final db = AppDatabase(NativeDatabase(file));
    await db.select(db.localProfiles).get();
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 20);

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.preferRpe, isFalse);

    await reopened.close();
  });

  test('la v18 reaplica el parche muscular del catálogo y vacía el caché', () async {
    final db = AppDatabase(NativeDatabase(file));
    for (final companion in [
      ExercisesCompanion.insert(
        id: '0031',
        name: 'Curl con barra',
        bodyPart: 'upper arms',
        equipment: 'barbell',
        target: 'biceps',
        muscleGroup: 'forearms',
        secondaryMuscles: const Value('["forearms"]'),
      ),
      ExercisesCompanion.insert(
        id: '1003',
        name: 'Remo en sentadilla con banda',
        bodyPart: 'upper legs',
        equipment: 'band',
        target: 'glutes',
        muscleGroup: 'glutes',
        secondaryMuscles: const Value('["hamstrings","quadriceps","back"]'),
      ),
      ExercisesCompanion.insert(
        id: '0001',
        name: '3/4 sit-up',
        bodyPart: 'waist',
        equipment: 'body weight',
        target: 'abs',
        muscleGroup: 'hip flexors',
        secondaryMuscles: const Value('["hip flexors","lower back"]'),
      ),
    ]) {
      await db.into(db.exercises).insert(companion);
    }
    await db
        .into(db.muscleFatigue)
        .insert(
          MuscleFatigueCompanion.insert(
            localUserId: 'perfil-antiguo',
            muscle: 'hamstrings',
            fatigue: 1,
            raw: 100,
            computedAt: DateTime(2026, 1, 1),
          ),
        );
    await db.customStatement('PRAGMA user_version = 17');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final rows = await reopened.select(reopened.exercises).get();
    final byId = {for (final row in rows) row.id: row};

    // Secundario completado y muscle_group derivado del primero.
    expect(byId['0031']!.secondaryMuscles, '["forearms","brachialis"]');
    expect(byId['0031']!.muscleGroup, 'forearms');
    // muscle_group corregido en la única fila que no cumplía el invariante.
    expect(byId['1003']!.muscleGroup, 'hamstrings');
    expect(
      byId['1003']!.secondaryMuscles,
      '["hamstrings","quadriceps","back"]',
    );
    // Los ejercicios fuera del parche no se tocan.
    expect(byId['0001']!.target, 'abs');
    expect(byId['0001']!.muscleGroup, 'hip flexors');
    expect(byId['0001']!.secondaryMuscles, '["hip flexors","lower back"]');

    // El caché derivado se invalida para que se recalcule con los datos nuevos.
    final cache = await reopened.select(reopened.muscleFatigue).get();
    expect(cache, isEmpty);

    await reopened.close();
  });

  test(
    'la v19 migra solo descansos distintos de 90 y conserva los datos',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      final profile = await db.select(db.localProfiles).getSingle();
      for (final entry in [('0001', 90), ('0002', 120), ('0003', 15)]) {
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                id: entry.$1,
                name: 'Ejercicio ${entry.$1}',
                bodyPart: 'chest',
                equipment: 'barbell',
                target: 'pectorals',
                muscleGroup: 'chest',
                restSeconds: Value(entry.$2),
              ),
            );
      }
      final startedAt = DateTime(2026, 2, 1, 10);
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              id: 'workout-v18',
              localUserId: profile.localUserId,
              startedAt: startedAt,
              restPausedSeconds: const Value(45),
            ),
          );
      await db
          .into(db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              id: 'item-v18',
              workoutId: 'workout-v18',
              exerciseId: '0001',
              orderIndex: 1,
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              id: 'set-v18',
              workoutExerciseId: 'item-v18',
              orderIndex: 1,
              reps: const Value(8),
              completed: const Value(true),
            ),
          );
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'queue-v18',
              operation: 'upsert',
              targetTable: 'workouts',
              payload: '{"id":"workout-v18"}',
              nextAttemptAt: startedAt,
            ),
          );
      await db.customStatement('DROP TABLE exercise_preferences');
      await db.customStatement(
        'ALTER TABLE workout_exercises DROP COLUMN rest_ends_at',
      );
      await db.customStatement(
        'ALTER TABLE workout_exercises DROP COLUMN rest_paused_seconds',
      );
      await db.customStatement('PRAGMA user_version = 18');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 20);
      final preferences = await reopened
          .select(reopened.exercisePreferences)
          .get();
      expect(preferences, hasLength(2));
      expect(preferences.map((row) => row.localUserId).toSet(), {
        profile.localUserId,
      });
      expect(
        {for (final row in preferences) row.exerciseId: row.restSeconds},
        {'0002': 120, '0003': 15},
      );
      final exercises = await reopened.select(reopened.exercises).get();
      expect(
        {for (final row in exercises) row.id: row.restSeconds},
        {'0001': 90, '0002': 120, '0003': 15},
      );
      final workout = await reopened.select(reopened.workouts).getSingle();
      expect(workout.restPausedSeconds, 45);
      expect(workout.restEndsAt, isNull);
      final item = await reopened.select(reopened.workoutExercises).getSingle();
      expect(item.restEndsAt, isNull);
      expect(item.restPausedSeconds, isNull);
      expect(await reopened.select(reopened.workoutSets).get(), hasLength(1));
      final queue = await reopened.select(reopened.syncQueue).getSingle();
      expect(queue.id, 'queue-v18');
      expect(queue.payload, '{"id":"workout-v18"}');

      await expectLater(
        reopened.customStatement(
          'INSERT INTO exercise_preferences '
          '(id, local_user_id, exercise_id, rest_seconds, created_at, updated_at) '
          "VALUES ('invalid-rest', '${profile.localUserId}', '0001', 14, 1, 1)",
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        reopened.customStatement(
          'INSERT INTO exercise_preferences '
          '(id, local_user_id, exercise_id, target, created_at, updated_at) '
          "VALUES ('invalid-muscles', '${profile.localUserId}', '0001', "
          "'pectorals', 1, 1)",
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        reopened.customStatement(
          "UPDATE workout_exercises SET rest_ends_at = 100, "
          "rest_paused_seconds = 10 WHERE id = 'item-v18'",
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        reopened.customStatement(
          "UPDATE workout_exercises SET rest_paused_seconds = -1 "
          "WHERE id = 'item-v18'",
        ),
        throwsA(isA<SqliteException>()),
      );
      await reopened.close();
    },
  );

  test(
    'la v19 interrumpida no duplica ni pisa una preferencia existente',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      final profile = await db.select(db.localProfiles).getSingle();
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: '0001',
              name: 'Press',
              bodyPart: 'chest',
              equipment: 'barbell',
              target: 'pectorals',
              muscleGroup: 'chest',
              restSeconds: const Value(120),
            ),
          );
      final createdAt = DateTime(2026, 1, 1);
      await db
          .into(db.exercisePreferences)
          .insert(
            ExercisePreferencesCompanion.insert(
              id: 'existing-preference',
              localUserId: profile.localUserId,
              exerciseId: '0001',
              restSeconds: const Value(135),
              target: const Value('pectorals'),
              muscleGroup: const Value('triceps'),
              secondaryMuscles: const Value('["triceps"]'),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await db.customStatement(
        'ALTER TABLE workout_exercises DROP COLUMN rest_ends_at',
      );
      await db.customStatement(
        'ALTER TABLE workout_exercises DROP COLUMN rest_paused_seconds',
      );
      await db.customStatement('PRAGMA user_version = 18');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final preferences = await reopened
          .select(reopened.exercisePreferences)
          .get();
      expect(preferences, hasLength(1));
      expect(preferences.single.id, 'existing-preference');
      expect(preferences.single.restSeconds, 135);
      expect(preferences.single.target, 'pectorals');
      expect(preferences.single.muscleGroup, 'triceps');
      expect(preferences.single.secondaryMuscles, '["triceps"]');
      expect(preferences.single.createdAt, createdAt);
      final columns = await reopened
          .customSelect(
            "SELECT name FROM pragma_table_info('workout_exercises')",
          )
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['rest_ends_at', 'rest_paused_seconds']),
      );
      await reopened.close();
    },
  );

  test('una base creada como v20 no ejecuta el backfill', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
            restSeconds: const Value(120),
          ),
        );

    expect(db.schemaVersion, 20);
    expect(await db.select(db.exercisePreferences).get(), isEmpty);
    await db.close();
  });

  test('la v19 migra a v20 y conserva catálogo y referencias', () async {
    final db = AppDatabase(NativeDatabase(file));
    final profile = await db.select(db.localProfiles).getSingle();
    final createdAt = DateTime(2026, 1, 1);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press conservado',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["triceps"]'),
            restSeconds: const Value(120),
          ),
        );
    await db
        .into(db.exercisePreferences)
        .insert(
          ExercisePreferencesCompanion.insert(
            id: 'preference-v19',
            localUserId: profile.localUserId,
            exerciseId: '0001',
            restSeconds: const Value(135),
            target: const Value('pectorals'),
            muscleGroup: const Value('triceps'),
            secondaryMuscles: const Value('["triceps"]'),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    await db
        .into(db.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'routine-v19',
            localUserId: profile.localUserId,
            name: 'Rutina conservada',
          ),
        );
    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            id: 'routine-item-v19',
            routineId: 'routine-v19',
            exerciseId: '0001',
            orderIndex: 1,
          ),
        );
    await db
        .into(db.routineSets)
        .insert(
          RoutineSetsCompanion.insert(
            id: 'routine-set-v19',
            routineExerciseId: 'routine-item-v19',
            orderIndex: 1,
            weightKg: const Value(82.5),
            reps: const Value(10),
            restSeconds: const Value(120),
          ),
        );
    await db
        .into(db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: 'workout-v19',
            localUserId: profile.localUserId,
            startedAt: createdAt,
            endedAt: Value(createdAt.add(const Duration(hours: 1))),
            status: const Value('finished'),
            restPausedSeconds: const Value(45),
          ),
        );
    await db
        .into(db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            id: 'item-v19',
            workoutId: 'workout-v19',
            exerciseId: '0001',
            orderIndex: 1,
            restPausedSeconds: const Value(30),
          ),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            id: 'set-v19',
            workoutExerciseId: 'item-v19',
            orderIndex: 1,
            weightKg: const Value(80),
            reps: const Value(8),
            restSeconds: const Value(105),
            completed: const Value(true),
          ),
        );
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: 'queue-v19',
            operation: 'upsert',
            targetTable: 'workouts',
            payload: '{"id":"workout-v19"}',
            nextAttemptAt: createdAt,
          ),
        );
    for (final column in [
      'local_user_id',
      'image_storage_path',
      'image_mime_type',
      'image_upload_status',
      'updated_at',
      'origin',
    ]) {
      await db.customStatement('ALTER TABLE exercises DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 19');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final exercise = await reopened.select(reopened.exercises).getSingle();
    expect(exercise.name, 'Press conservado');
    expect(exercise.restSeconds, 120);
    expect(exercise.secondaryMuscles, '["triceps"]');
    expect(exercise.origin, 'catalog');
    expect(exercise.localUserId, isNull);
    expect(exercise.imageStoragePath, isNull);
    expect(exercise.imageMimeType, isNull);
    expect(exercise.imageUploadStatus, isNull);
    expect(exercise.updatedAt, isNull);
    final preference = await reopened
        .select(reopened.exercisePreferences)
        .getSingle();
    expect(preference.id, 'preference-v19');
    expect(preference.restSeconds, 135);
    expect(preference.target, 'pectorals');
    expect(preference.muscleGroup, 'triceps');
    expect(preference.secondaryMuscles, '["triceps"]');
    expect(
      (await reopened.select(reopened.routines).getSingle()).name,
      'Rutina conservada',
    );
    final plannedSet = await reopened.select(reopened.routineSets).getSingle();
    expect(plannedSet.weightKg, 82.5);
    expect(plannedSet.reps, 10);
    expect(plannedSet.restSeconds, 120);
    final workout = await reopened.select(reopened.workouts).getSingle();
    expect(workout.status, 'finished');
    expect(workout.restPausedSeconds, 45);
    expect(
      (await reopened.select(reopened.workoutExercises).getSingle())
          .restPausedSeconds,
      30,
    );
    final set = await reopened.select(reopened.workoutSets).getSingle();
    expect(set.weightKg, 80);
    expect(set.reps, 8);
    expect(set.restSeconds, 105);
    final queue = await reopened.select(reopened.syncQueue).getSingle();
    expect(queue.id, 'queue-v19');
    expect(queue.payload, '{"id":"workout-v19"}');

    await reopened
        .into(reopened.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'custom_v20',
            name: 'Propio',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pectorals',
            createdAt: Value(createdAt),
            origin: const Value('custom'),
            localUserId: Value(profile.localUserId),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(createdAt),
          ),
        );
    await expectLater(
      reopened.customStatement(
        'INSERT INTO exercises '
        '(id, name, body_part, equipment, target, muscle_group, origin, '
        'local_user_id, image_upload_status, updated_at) VALUES '
        "('custom_sin_dueno', 'Inválido', 'chest', 'barbell', 'pectorals', "
        "'pectorals', 'custom', NULL, 'none', 1)",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      (await reopened.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      20,
    );
    await reopened.close();
  });

  test('la v20 declara origen y metadata de imagen del contrato', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final columns = await db
        .customSelect("SELECT name, pk FROM pragma_table_info('exercises')")
        .get();

    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      containsAll([
        'origin',
        'local_user_id',
        'image_storage_path',
        'image_mime_type',
        'image_upload_status',
        'updated_at',
      ]),
    );
    expect(
      columns
          .singleWhere((row) => row.read<String>('name') == 'id')
          .read<int>('pk'),
      1,
    );
    final instructionColumns = await db
        .customSelect(
          "SELECT name FROM pragma_table_info('exercise_instructions')",
        )
        .get();
    expect(
      instructionColumns.map((row) => row.read<String>('name')),
      containsAll(['exercise_id', 'language', 'step_number', 'instruction']),
    );
    final schema = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE name = 'exercises'")
        .getSingle();
    final sql = schema.read<String>('sql');
    expect(sql, contains("DEFAULT 'catalog'"));
    expect(sql, contains("'pending_upload'"));
    expect(sql, contains("'pending_delete'"));
    expect(sql, contains("'image/webp'"));
    await db.close();
  });

  test('la v20 interrumpida conserva columnas y filas custom', () async {
    final db = AppDatabase(NativeDatabase(file));
    final profile = await db.select(db.localProfiles).getSingle();
    final createdAt = DateTime(2026, 1, 1);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'custom_interrupted',
            name: 'Custom conservado',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            createdAt: Value(createdAt),
            origin: const Value('custom'),
            localUserId: Value(profile.localUserId),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(createdAt),
            restSeconds: const Value(135),
          ),
        );
    await db.customStatement(
      'ALTER TABLE exercises DROP COLUMN image_storage_path',
    );
    await db.customStatement(
      'ALTER TABLE exercises DROP COLUMN image_mime_type',
    );
    await db.customStatement('PRAGMA user_version = 19');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final exercise = await reopened.select(reopened.exercises).getSingle();
    expect(exercise.id, 'custom_interrupted');
    expect(exercise.origin, 'custom');
    expect(exercise.localUserId, profile.localUserId);
    expect(exercise.imageUploadStatus, 'none');
    expect(exercise.imageStoragePath, isNull);
    expect(exercise.imageMimeType, isNull);
    expect(exercise.restSeconds, 135);
    expect(exercise.createdAt, createdAt);
    expect(exercise.updatedAt, createdAt);
    expect(
      (await reopened.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      20,
    );
    await reopened.close();
  });
}
