import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/template_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RoutineRepository routines;
  late TemplateRepository templates;
  late List<({String operation, String table, Map<String, dynamic> payload})>
  enqueued;

  Map<String, dynamic> singleDay() => {
    'id': 't-full',
    'name': 'Cuerpo completo',
    'description': 'Sesión de ejemplo',
    'category': 'Full Body',
    'level': 'Principiante',
    'goal': 'Adaptación',
    'target_days': 3,
    'weeks': 6,
    'template_days': [
      {
        'id': 'd-a',
        'template_id': 't-full',
        'order_index': 1,
        'name': 'Sesión A',
        'template_exercises': [
          {
            'id': 'e-bench',
            'template_day_id': 'd-a',
            'exercise_id': '0025',
            'order_index': 1,
            'template_sets': [
              {
                'id': 's-1',
                'template_exercise_id': 'e-bench',
                'order_index': 1,
                'set_type': 'normal',
                'weight_kg': 40,
                'reps': 8,
                'rir': 2,
                'rest_seconds': 90,
              },
              {
                'id': 's-2',
                'template_exercise_id': 'e-bench',
                'order_index': 2,
                'set_type': 'normal',
                'weight_kg': 40,
                'reps': 8,
                'rir': 2,
                'rest_seconds': 90,
              },
              {
                'id': 's-3',
                'template_exercise_id': 'e-bench',
                'order_index': 3,
                'set_type': 'normal',
                'weight_kg': 40,
                'reps': 8,
                'rir': 2,
                'rest_seconds': 90,
              },
            ],
          },
          {
            'id': 'e-ghost',
            'template_day_id': 'd-a',
            'exercise_id': '9999',
            'order_index': 2,
            'template_sets': [
              {
                'id': 's-4',
                'template_exercise_id': 'e-ghost',
                'order_index': 1,
                'set_type': 'normal',
                'weight_kg': 0,
                'reps': 10,
                'rir': 1,
                'rest_seconds': 60,
              },
            ],
          },
        ],
      },
    ],
  };

  Map<String, dynamic> program() => {
    'id': 't-ppl',
    'name': 'PPL',
    'description': 'Programa de ejemplo',
    'category': 'Push/Pull/Legs',
    'level': 'Intermedio',
    'goal': 'Hipertrofia',
    'target_days': 6,
    'weeks': 8,
    'template_days': [
      for (final (index, day) in [
        ('Empuje', '0025'),
        ('Pierna', '0043'),
      ].indexed)
        {
          'id': 'pd-$index',
          'template_id': 't-ppl',
          'order_index': index + 1,
          'name': day.$1,
          'template_exercises': [
            {
              'id': 'pe-$index',
              'template_day_id': 'pd-$index',
              'exercise_id': day.$2,
              'order_index': 1,
              'template_sets': [
                {
                  'id': 'ps-$index',
                  'template_exercise_id': 'pe-$index',
                  'order_index': 1,
                  'set_type': 'normal',
                  'weight_kg': 0,
                  'reps': 5,
                  'rir': 2,
                  'rest_seconds': 180,
                },
              ],
            },
          ],
        },
    ],
  };

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];

    await (db.update(db.localProfiles)..where((t) => t.id.equals(1))).write(
      const LocalProfilesCompanion(localUserId: Value('local-1')),
    );
    for (final (id, name) in [
      ('0025', 'Press de banca'),
      ('0043', 'Sentadilla'),
    ]) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: id,
              name: name,
              bodyPart: 'chest',
              equipment: 'barbell',
              target: 'pectorals',
              muscleGroup: 'chest',
            ),
          );
    }

    final workouts = WorkoutRepository(db);
    routines = RoutineRepository(
      db,
      workouts,
      enqueue: (operation, table, payload) async {
        enqueued.add((
          operation: operation,
          table: table,
          payload: jsonDecode(payload) as Map<String, dynamic>,
        ));
      },
    );
    templates = TemplateRepository(
      db,
      routines,
      fetcher: () async => [singleDay(), program()],
    );
  });

  tearDown(() => db.close());

  test('refresh cachea las plantillas y las deja consultables', () async {
    expect(await templates.refresh(), 2);

    final all = await templates.cachedTemplates();
    expect(all.map((t) => t.id), containsAll(['t-full', 't-ppl']));

    final search = await templates.watchTemplates(query: 'cuerpo').first;
    expect(search.single.id, 't-full');

    final filtered = await templates
        .watchTemplates(category: 'Push/Pull/Legs')
        .first;
    expect(filtered.single.id, 't-ppl');
  });

  test('detail devuelve días, series y el catálogo resuelto', () async {
    await templates.refresh();

    final detail = await templates.detail('t-full');
    expect(detail, isNotNull);
    expect(detail!.template.name, 'Cuerpo completo');
    expect(detail.days.single.day.name, 'Sesión A');

    final exercises = detail.days.single.exercises;
    expect(exercises, hasLength(2));
    expect(exercises.first.exercise?.name, 'Press de banca');
    expect(exercises.first.sets, hasLength(3));
    expect(exercises.last.exercise, isNull);
  });

  test('importa una plantilla de un día como una rutina propia', () async {
    await templates.refresh();

    final result = await templates.importTemplate('t-full');

    expect(result.routines, hasLength(1));
    expect(result.skippedExercises, 1);

    final routine = result.routines.single;
    expect(routine.name, 'Cuerpo completo');
    expect(routine.category, 'Full Body');
    expect(routine.level, 'Principiante');
    expect(routine.goal, 'Adaptación');
    expect(routine.targetDays, 3);

    final exercises = await routines.routineExercises(routine.id);
    expect(exercises, hasLength(1));
    expect(exercises.single.item.exerciseId, '0025');

    final sets = await routines.routineSets(exercises.single.item.id);
    expect(sets, hasLength(3));
    expect(sets.first.reps, 8);
    expect(sets.first.rir, 2);
    expect(sets.first.restSeconds, 90);
    expect(sets.first.weightKg, 40);
  });

  test('importa un programa como una rutina por día', () async {
    await templates.refresh();

    final result = await templates.importTemplate('t-ppl');

    expect(result.routines, hasLength(2));
    expect(result.skippedExercises, 0);
    expect(result.routines.map((r) => r.name), [
      'PPL · Empuje',
      'PPL · Pierna',
    ]);
    for (final routine in result.routines) {
      expect(routine.category, 'Push/Pull/Legs');
      expect(routine.targetDays, 6);
    }
  });

  test('refresh sustituye la cache anterior', () async {
    await templates.refresh();

    var data = [program()];
    templates = TemplateRepository(db, routines, fetcher: () async => data);

    expect(await templates.refresh(), 1);
    final cached = await templates.cachedTemplates();
    expect(cached.single.id, 't-ppl');
    expect(await templates.detail('t-full'), isNull);

    data = const [];
    expect(await templates.refresh(), 0);
    expect(await templates.cachedTemplates(), isEmpty);
  });
}
