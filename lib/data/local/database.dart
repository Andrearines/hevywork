import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'tables/body_metrics.dart';
import 'tables/exercises.dart';
import 'tables/goals.dart';
import 'tables/local_profiles.dart';
import 'tables/muscle_fatigue.dart';
import 'tables/profiles.dart';
import 'tables/progress_photos.dart';
import 'tables/routines.dart';
import 'tables/sync_queue.dart';
import 'tables/templates.dart';
import 'tables/workouts.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseInstructions,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    Routines,
    RoutineExercises,
    RoutineSets,
    Goals,
    BodyMetrics,
    MuscleFatigue,
    Profiles,
    LocalProfiles,
    ProgressPhotos,
    Templates,
    TemplateDays,
    TemplateExercises,
    TemplateSets,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 17;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: _createSchema,
    onUpgrade: (Migrator m, int from, int to) async {
      if (await _needsRecreation(m)) {
        await _recreateSchema(m);
        return;
      }
      // Cada paso es idempotente: una migración interrumpida (app
      // cerrada a mitad de `onUpgrade`) deja el esquema ya avanzado con
      // el `user_version` atrasado, y un `ALTER TABLE`/`CREATE TABLE`
      // directo revienta con «duplicate column/table» y la app no abre.
      if (from < 2) {
        await _addColumnIfMissing(m, syncQueue, syncQueue.status);
      }
      if (from < 4) {
        // Spec 002: descanso por ejercicio y temporizador persistido.
        await _addColumnIfMissing(m, exercises, exercises.restSeconds);
        await _addColumnIfMissing(m, workouts, workouts.restEndsAt);
        await _addColumnIfMissing(m, workouts, workouts.restPausedSeconds);
      }
      if (from < 5) {
        // Spec 002 (RF-9): marcador de sesión reanudable.
        await _addColumnIfMissing(
          m,
          localProfiles,
          localProfiles.lastActiveWorkoutId,
        );
      }
      if (from < 6) {
        // Spec 004 (RF-1): rutinas y sus ejercicios.
        await _createTableIfMissing(m, routines);
        await _createTableIfMissing(m, routineExercises);
      }
      if (from < 7) {
        // Spec 005 (RF-1/RF-2): metas del usuario.
        await _createTableIfMissing(m, goals);
      }
      if (from < 8) {
        // Spec 004 (RF-1): series planificadas de la rutina y descanso
        // planificado clonado a la sesión.
        await _createTableIfMissing(m, routineSets);
        await _addColumnIfMissing(m, workoutSets, workoutSets.restSeconds);
      }
      if (from < 9) {
        // Spec 004 (RF-2/RF-4): vínculo de la serie de la sesión con la
        // serie planificada que la originó.
        await _addColumnIfMissing(m, workoutSets, workoutSets.routineSetId);
      }
      if (from < 10) {
        // Spec 006 (RF-1): registro diario de peso y medidas. Consolida
        // el `body_weight` de la 005: una fila por `(user, día)` con peso
        // opcional, medidas y notas.
        await _createTableIfMissing(m, bodyMetrics);
        final hasBodyWeight = await m.database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type='table' AND name='body_weight'",
            )
            .getSingleOrNull();
        if (hasBodyWeight != null) {
          final oldRows = await m.database
              .customSelect(
                'SELECT measured_at, local_user_id, weight_kg, '
                'created_at, updated_at FROM body_weight',
              )
              .get();
          for (final row in oldRows) {
            final measured = DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('measured_at') * 1000,
            );
            final day = DateTime(measured.year, measured.month, measured.day);
            await m.database.customStatement(
              // `OR IGNORE`: si una copia previa interrumpida ya dejó
              // la fila del día, se conserva sin reñir con la PK.
              'INSERT OR IGNORE INTO body_metrics '
              '(date, local_user_id, weight_kg, created_at, updated_at) '
              'VALUES (?, ?, ?, ?, ?)',
              [
                day.millisecondsSinceEpoch ~/ 1000,
                row.read<String>('local_user_id'),
                row.read<double>('weight_kg'),
                row.read<int>('created_at'),
                row.read<int>('updated_at'),
              ],
            );
          }
          await m.database.customStatement('DROP TABLE IF EXISTS body_weight');
        }
      }
      if (from < 11) {
        // Spec 007 (RF-6): cache local del mapa de fatiga. Es dato
        // derivado: no viaja al remoto, se recalcula tras cada sync.
        await _createTableIfMissing(m, muscleFatigue);
      }
      if (from < 12) {
        // Spec 008 (RF-29/RF-31): preferencia RIR/RPE del perfil.
        await _addColumnIfMissing(m, localProfiles, localProfiles.preferRpe);
      }
      if (from < 13) {
        // Spec 008 (T-5): metadata de planificación de la rutina.
        await _addColumnIfMissing(m, routines, routines.category);
        await _addColumnIfMissing(m, routines, routines.level);
        await _addColumnIfMissing(m, routines, routines.goal);
        await _addColumnIfMissing(m, routines, routines.targetDays);
      }
      if (from < 14) {
        // Spec 009 (RF-5): fotos de progreso con cola de subida.
        await _createTableIfMissing(m, progressPhotos);
      }
      if (from < 15) {
        // Spec 009 (RF-1/RF-4): composición corporal y datos del perfil
        // para la estimación US Navy.
        await _addColumnIfMissing(m, bodyMetrics, bodyMetrics.bodyFatPct);
        await _addColumnIfMissing(m, bodyMetrics, bodyMetrics.leanMassKg);
        await _addColumnIfMissing(m, localProfiles, localProfiles.sex);
        await _addColumnIfMissing(m, localProfiles, localProfiles.heightCm);
      }
      if (from < 16) {
        // Spec 010 (RF-3): cache local del catálogo de plantillas
        // comunitarias para navegar sin conexión.
        await _createTableIfMissing(m, templates);
        await _createTableIfMissing(m, templateDays);
        await _createTableIfMissing(m, templateExercises);
        await _createTableIfMissing(m, templateSets);
      }
      if (from < 18) {
        // Spec 012+: avatar del perfil (foto de perfil).
        await _addColumnIfMissing(m, localProfiles, localProfiles.avatarUrl);
      }
    },
  );

  /// Crea [table] solo si no existe ya (ver comentario en `onUpgrade`).
  Future<void> _createTableIfMissing(Migrator m, TableInfo table) async {
    final existing = await m.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = '${table.aliasedName}'",
        )
        .getSingleOrNull();
    if (existing != null) return;
    await m.createTable(table);
  }

  /// Añade [column] a [table] solo si aún no existe (ver comentario en
  /// `onUpgrade`).
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final info = await m.database
        .customSelect('PRAGMA table_info("${table.aliasedName}")')
        .get();
    if (info.any((row) => row.read<String>('name') == column.$name)) return;
    await m.addColumn(table, column);
  }

  Future<void> _createSchema(Migrator m) async {
    await m.createAll();
    await _createIndexes();
    await into(localProfiles)
        .insert(LocalProfilesCompanion.insert(localUserId: const Uuid().v4()));
  }

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_workouts_status_ended '
          'ON workouts(status, ended_at)',
      'CREATE INDEX IF NOT EXISTS idx_workout_exercises_workout_order '
          'ON workout_exercises(workout_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_workout_exercises_exercise '
          'ON workout_exercises(exercise_id)',
      'CREATE INDEX IF NOT EXISTS idx_workout_sets_exercise_order '
          'ON workout_sets(workout_exercise_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_routine_exercises_routine_order '
          'ON routine_exercises(routine_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_routine_sets_exercise_order '
          'ON routine_sets(routine_exercise_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_progress_photos_user_date '
          'ON progress_photos(local_user_id, date)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_next '
          'ON sync_queue(status, next_attempt_at)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<bool> _needsRecreation(Migrator m) async {
    const probes = [
      'SELECT image_path FROM exercises LIMIT 1',
      'SELECT language FROM exercise_instructions LIMIT 1',
      'SELECT status FROM sync_queue LIMIT 1',
    ];

    for (final probe in probes) {
      try {
        await m.database.customSelect(probe).get();
      } on SqliteException catch (error) {
        final missing =
            error.message.contains('no such column') ||
            error.message.contains('no such table');
        if (!missing) rethrow;
        return true;
      }
    }
    return false;
  }

  Future<void> _recreateSchema(Migrator m) async {
    final virtualTables = await m.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND sql LIKE 'CREATE VIRTUAL TABLE%'",
        )
        .get();
    for (final row in virtualTables) {
      await m.deleteTable(row.read<String>('name'));
    }

    final tables = allSchemaEntities
        .whereType<TableInfo<Table, Object?>>()
        .toList()
        .reversed;
    for (final table in tables) {
      await m.drop(table);
    }

    await _createSchema(m);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(
      '${dbFolder.path}${Platform.pathSeparator}hevywork.sqlite',
    );
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA synchronous = NORMAL');
      },
    );
  });
}
