import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';
import 'routine_repository.dart';

/// Origen de las plantillas: por defecto Supabase; inyectable en tests.
typedef TemplateFetcher = Future<List<Map<String, dynamic>>> Function();

/// Fila de ejercicio de una plantilla con su entrada del catálogo (null si el
/// ejercicio ya no existe: la importación lo omite y avisa).
class TemplateExerciseDetail {
  const TemplateExerciseDetail({
    required this.item,
    required this.exercise,
    required this.sets,
  });

  final TemplateExercise item;
  final Exercise? exercise;
  final List<TemplateSet> sets;
}

class TemplateDayDetail {
  const TemplateDayDetail({required this.day, required this.exercises});

  final TemplateDay day;
  final List<TemplateExerciseDetail> exercises;
}

class TemplateDetail {
  const TemplateDetail({required this.template, required this.days});

  final CommunityTemplate template;
  final List<TemplateDayDetail> days;
}

class TemplateImportResult {
  const TemplateImportResult({
    required this.routines,
    required this.skippedExercises,
  });

  final List<Routine> routines;
  final int skippedExercises;
}

/// Catálogo compartido de plantillas comunitarias (spec 010): solo lectura,
/// cacheado en drift para funcionar sin conexión tras la primera carga.
class TemplateRepository {
  TemplateRepository(
    this._db,
    this._routines, {
    SupabaseClient? supabase,
    this.fetcher,
  }) : _client = supabase;

  final AppDatabase _db;
  final RoutineRepository _routines;
  final SupabaseClient? _client;
  final TemplateFetcher? fetcher;

  Stream<List<CommunityTemplate>> watchTemplates({
    String query = '',
    String? category,
    String? level,
  }) {
    final statement = _db.select(_db.templates);
    final term = query.trim();
    if (term.isNotEmpty) {
      statement.where((t) => t.name.like('%$term%'));
    }
    if (category != null && category.isNotEmpty) {
      statement.where((t) => t.category.equals(category));
    }
    if (level != null && level.isNotEmpty) {
      statement.where((t) => t.level.equals(level));
    }
    statement.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return statement.watch();
  }

  Future<List<CommunityTemplate>> cachedTemplates() => (_db.select(
    _db.templates,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> refresh() async {
    final fetch = fetcher ?? _fetchFromSupabase;
    final data = await fetch();

    await _db.transaction(() async {
      await _db.delete(_db.templateSets).go();
      await _db.delete(_db.templateExercises).go();
      await _db.delete(_db.templateDays).go();
      await _db.delete(_db.templates).go();

      for (final template in data) {
        await _insertTemplate(template);
      }
    });
    return data.length;
  }

  Future<void> _insertTemplate(Map<String, dynamic> template) async {
    final id = template['id'] as String;
    await _db
        .into(_db.templates)
        .insert(
          TemplatesCompanion.insert(
            id: id,
            name: template['name'] as String,
            description: Value(template['description'] as String?),
            category: Value(template['category'] as String?),
            level: Value(template['level'] as String?),
            goal: Value(template['goal'] as String?),
            targetDays: Value(template['target_days'] as int?),
            weeks: Value(template['weeks'] as int?),
          ),
        );

    for (final rawDay in (template['template_days'] as List? ?? const [])) {
      final day = rawDay as Map<String, dynamic>;
      final dayId = day['id'] as String;
      await _db
          .into(_db.templateDays)
          .insert(
            TemplateDaysCompanion.insert(
              id: dayId,
              templateId: id,
              orderIndex: day['order_index'] as int,
              name: day['name'] as String,
            ),
          );

      for (final rawItem in (day['template_exercises'] as List? ?? const [])) {
        final item = rawItem as Map<String, dynamic>;
        final itemId = item['id'] as String;
        await _db
            .into(_db.templateExercises)
            .insert(
              TemplateExercisesCompanion.insert(
                id: itemId,
                dayId: dayId,
                exerciseId: item['exercise_id'] as String,
                orderIndex: item['order_index'] as int,
              ),
            );

        for (final rawSet in (item['template_sets'] as List? ?? const [])) {
          final set = rawSet as Map<String, dynamic>;
          await _db
              .into(_db.templateSets)
              .insert(
                TemplateSetsCompanion.insert(
                  id: set['id'] as String,
                  templateExerciseId: itemId,
                  orderIndex: set['order_index'] as int,
                  setType: Value(set['set_type'] as String? ?? 'normal'),
                  weightKg: Value((set['weight_kg'] as num? ?? 0).toDouble()),
                  reps: Value(set['reps'] as int? ?? 0),
                  rir: Value(set['rir'] as int? ?? 0),
                  restSeconds: Value(set['rest_seconds'] as int?),
                ),
              );
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromSupabase() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase no está configurado');
    }
    final rows = await client
        .from('templates')
        .select(
          'id,name,description,category,level,goal,target_days,weeks,'
          'template_days(id,template_id,order_index,name,'
          'template_exercises(id,template_day_id,exercise_id,order_index,'
          'template_sets(id,template_exercise_id,order_index,set_type,'
          'weight_kg,reps,rir,rest_seconds)))',
        );
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<TemplateDetail?> detail(String id) async {
    final template = await (_db.select(
      _db.templates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (template == null) return null;

    final days =
        await (_db.select(_db.templateDays)
              ..where((d) => d.templateId.equals(id))
              ..orderBy([(d) => OrderingTerm.asc(d.orderIndex)]))
            .get();

    final dayDetails = <TemplateDayDetail>[];
    for (final day in days) {
      final items =
          await (_db.select(_db.templateExercises)
                ..where((e) => e.dayId.equals(day.id))
                ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
              .get();

      final exercises = <TemplateExerciseDetail>[];
      for (final item in items) {
        final sets =
            await (_db.select(_db.templateSets)
                  ..where((s) => s.templateExerciseId.equals(item.id))
                  ..orderBy([(s) => OrderingTerm.asc(s.orderIndex)]))
                .get();
        final exercise = await (_db.select(
          _db.exercises,
        )..where((e) => e.id.equals(item.exerciseId))).getSingleOrNull();
        exercises.add(
          TemplateExerciseDetail(item: item, exercise: exercise, sets: sets),
        );
      }
      dayDetails.add(TemplateDayDetail(day: day, exercises: exercises));
    }

    return TemplateDetail(template: template, days: dayDetails);
  }

  /// Clona la plantilla en rutinas propias (RF-5/RF-6/RF-7): una rutina si
  /// tiene un solo día, una por día si es un programa. No mantiene vínculo
  /// vivo con la plantilla.
  Future<TemplateImportResult> importTemplate(String id) async {
    final detail = await this.detail(id);
    if (detail == null) {
      throw StateError('Plantilla no encontrada');
    }

    final routines = <Routine>[];
    var skipped = 0;
    final singleDay = detail.days.length == 1;

    for (final day in detail.days) {
      final drafts = <RoutineExerciseDraft>[];
      for (final entry in day.exercises) {
        if (entry.exercise == null) {
          skipped++;
          continue;
        }
        drafts.add(
          RoutineExerciseDraft(
            exerciseId: entry.item.exerciseId,
            sets: [
              for (final set in entry.sets)
                RoutineSetDraft(
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
      if (drafts.isEmpty) continue;

      routines.add(
        await _routines.createRoutine(
          name: singleDay
              ? detail.template.name
              : '${detail.template.name} · ${day.day.name}',
          description: detail.template.description,
          category: detail.template.category,
          level: detail.template.level,
          goal: detail.template.goal,
          targetDays: detail.template.targetDays,
          exercises: drafts,
        ),
      );
    }

    return TemplateImportResult(routines: routines, skippedExercises: skipped);
  }
}
