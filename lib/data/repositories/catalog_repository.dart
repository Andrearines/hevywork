import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../domain/exercise_filter.dart';
import '../../domain/search_text.dart';
import '../local/database.dart';

/// Resultado paginado de [CatalogRepository.searchPage]: la página pedida y
/// el total de coincidencias para el contador (RF-4 de la 003).
typedef ExercisesPage = ({List<Exercise> exercises, int total});

/// Opciones por dimensión para los filtros (RF-3 de la 003), extraídas de
/// la base local, alfabéticas y sin traducir (§9).
typedef FilterOptions = ({
  List<String> bodyParts,
  List<String> equipments,
  List<String> targets,
  List<String> muscleGroups,
  List<String> secondaryMuscles,
});

class CatalogRepository {
  static const String assetPath = 'assets/exercises.json';

  final AppDatabase _db;

  FilterOptions? _filterOptionsCache;

  CatalogRepository(this._db);

  /// Inicializa el catálogo local si está vacío.
  /// Lee el asset de metadatos y lo inserta en la base de datos sin red.
  /// Nunca borra ni sobrescribe ejercicios existentes (RF-1 / RF-4).
  Future<void> initializeCatalogIfEmpty() async {
    final count = await _db.exercises.count().getSingle();
    if (count > 0) return;

    final raw = await rootBundle.loadString(assetPath);
    final records = jsonDecode(raw) as List<dynamic>;

    final exercises = <ExercisesCompanion>[];
    final instructions = <ExerciseInstructionsCompanion>[];

    for (final item in records.cast<Map<String, dynamic>>()) {
      final id = item['id'] as String;
      final secondary = item['secondary_muscles'] as List<dynamic>?;

      exercises.add(ExercisesCompanion.insert(
        id: id,
        name: item['name'] as String,
        bodyPart: item['body_part'] as String,
        equipment: item['equipment'] as String,
        target: item['target'] as String,
        muscleGroup: item['muscle_group'] as String,
        secondaryMuscles: Value(
          secondary == null ? null : jsonEncode(secondary.cast<String>()),
        ),
        mediaId: Value(item['media_id'] as String?),
        imagePath: Value(item['image'] as String?),
        gifPath: Value(item['gif_url'] as String?),
        attribution: Value(item['attribution'] as String?),
        createdAt: Value(
          item['created_at'] == null
              ? null
              : DateTime.tryParse(item['created_at'] as String),
        ),
      ));

      final steps =
          (item['instruction_steps'] as Map<String, dynamic>?) ?? const {};
      steps.forEach((language, rawSteps) {
        final list = (rawSteps as List<dynamic>).cast<String>();
        for (var i = 0; i < list.length; i++) {
          instructions.add(ExerciseInstructionsCompanion.insert(
            exerciseId: id,
            language: language,
            stepNumber: i + 1,
            instruction: list[i],
          ));
        }
      });
    }

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAll(_db.exercises, exercises);
        batch.insertAll(_db.exerciseInstructions, instructions);
      });
    });
    _filterOptionsCache = null;
  }

  /// Búsqueda simple de ejercicios
  Future<List<Exercise>> searchExercises(String query) {
    return (_db.select(_db.exercises)
          ..where((t) => t.name.like('%$query%'))
          ..limit(50))
        .get();
  }

  /// Un ejercicio por su id, para resolver las referencias de las metas
  /// (spec 005).
  Future<Exercise?> exerciseById(String id) async {
    return (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Nombre por id de ejercicio, para las tarjetas del dashboard de metas.
  Future<Map<String, String>> exerciseNames() async {
    final rows = await (_db.selectOnly(_db.exercises)
          ..addColumns([_db.exercises.id, _db.exercises.name]))
        .get();
    return {
      for (final row in rows)
        row.read(_db.exercises.id)!: row.read(_db.exercises.name)!,
    };
  }

  /// Búsqueda por nombre (RF-1) y filtros combinados (RF-3): los valores de
  /// cada dimensión suman (OR) y las dimensiones entre sí, y con la
  /// búsqueda, se multiplican (AND). Devuelve la página [offset,
  /// offset+pageSize) y el total de coincidencias.
  Future<ExercisesPage> searchPage({
    String query = '',
    ExerciseFilter filter = const ExerciseFilter(),
    int offset = 0,
    int pageSize = 50,
  }) async {
    final predicate = _searchPredicate(query, filter);
    final count = _db.exercises.id.count();
    final total = await (_db.selectOnly(_db.exercises)
          ..addColumns([count])
          ..where(predicate))
        .getSingle()
        .then((row) => row.read(count) ?? 0);
    final exercises = await (_db.select(_db.exercises)
          ..where((t) => predicate)
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(pageSize, offset: offset))
        .get();
    return (exercises: exercises, total: total);
  }

  /// Valores disponibles por dimensión (RF-3 de la 003), leídos de la base
  /// local; `secondary_muscles` se extrae del JSON de cada fila porque es
  /// una lista por ejercicio.
  Future<FilterOptions> filterOptions() async {
    final cached = _filterOptionsCache;
    if (cached != null) return cached;

    Future<List<String>> distinct(GeneratedColumn<String> column) async {
      final rows = await (_db.selectOnly(_db.exercises, distinct: true)
            ..addColumns([column])
            ..orderBy([OrderingTerm.asc(column)]))
          .get();
      return [for (final row in rows) row.read(column)!];
    }

    final secondary = <String>{};
    final column = _db.exercises.secondaryMuscles;
    final rows = await (_db.selectOnly(_db.exercises)
          ..addColumns([column]))
        .get();
    // En `selectOnly` las columnas viajan con su alias calificado
    // (`tabla.columna`), igual que los construye drift internamente.
    final key = '${column.tableName}.${column.name}';
    for (final row in rows) {
      final raw = row.rawData.readNullable<String>(key);
      if (raw == null) continue;
      secondary.addAll((jsonDecode(raw) as List<dynamic>).cast<String>());
    }

    final options = (
      bodyParts: await distinct(_db.exercises.bodyPart),
      equipments: await distinct(_db.exercises.equipment),
      targets: await distinct(_db.exercises.target),
      muscleGroups: await distinct(_db.exercises.muscleGroup),
      secondaryMuscles: secondary.toList()..sort(),
    );
    _filterOptionsCache = options;
    return options;
  }

  /// Grupos musculares disponibles, para las metas de volumen por músculo
  /// (spec 005, RF-1).
  Future<List<String>> muscleGroups() async {
    return await (_db.selectOnly(_db.exercises, distinct: true)
          ..addColumns([_db.exercises.muscleGroup])
          ..orderBy([OrderingTerm.asc(_db.exercises.muscleGroup)]))
        .map((row) => row.read(_db.exercises.muscleGroup)!)
        .get();
  }

  /// Predicado común para el contador (RF-4) y la página de resultados.
  Expression<bool> _searchPredicate(String query, ExerciseFilter filter) {
    final conditions = <Expression<bool>>[];

    final normalized = normalizeSearchText(query);
    if (normalized.isNotEmpty) {
      conditions.add(_db.exercises.name.like(
        '%${escapeLike(normalized)}%',
        escapeChar: r'\',
      ));
    }

    void addDimension(Column<String> column, Set<String> values) {
      if (values.isEmpty) return;
      conditions.add(
        values.length == 1 ? column.equals(values.first) : column.isIn(values),
      );
    }

    addDimension(_db.exercises.bodyPart, filter.bodyParts);
    addDimension(_db.exercises.equipment, filter.equipment);
    addDimension(_db.exercises.target, filter.targets);
    addDimension(_db.exercises.muscleGroup, filter.muscleGroups);

    if (filter.secondaryMuscles.isNotEmpty) {
      final secondary = FunctionCallExpression<String>('COALESCE', [
        _db.exercises.secondaryMuscles,
        const Constant<String>(''),
      ]);
      conditions.add(
        filter.secondaryMuscles
            .map((name) => secondary.like(
                  '%${escapeLike(name)}%',
                  escapeChar: r'\',
                ))
            .reduce((a, b) => a | b),
      );
    }

    if (conditions.isEmpty) return const Constant(true);
    return conditions.reduce((a, b) => a & b);
  }

  /// Escapa los comodines de `LIKE` (la barra, `%` y `_`) para que la
  /// búsqueda sea literal (RF-1).
  static String escapeLike(String text) =>
      text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  /// Ajusta el descanso por defecto de un ejercicio, 15–300 s (RF-5 de la
  /// 002). El CHECK de la columna replica el mismo rango en SQLite.
  Future<void> updateRestSeconds(String exerciseId, int seconds) async {
    if (seconds < 15 || seconds > 300) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'El descanso debe estar entre 15 y 300 segundos',
      );
    }
    await (_db.update(_db.exercises)..where((t) => t.id.equals(exerciseId)))
        .write(ExercisesCompanion(restSeconds: Value(seconds)));
  }
}