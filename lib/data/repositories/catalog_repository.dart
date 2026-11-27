import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

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
  String? _filterOptionsCacheOwner;

  CatalogRepository(this._db);

  /// Inicializa el catálogo local si está vacío.
  /// Lee el asset de metadatos y lo inserta en la base de datos sin red.
  /// Nunca borra ni sobrescribe ejercicios existentes (RF-1 / RF-4).
  Future<void> initializeCatalogIfEmpty() async {
    final master =
        await (_db.select(_db.exercises)
              ..where((t) => t.origin.equals('catalog'))
              ..limit(1))
            .getSingleOrNull();
    if (master != null) return;

    final raw = await rootBundle.loadString(assetPath);
    final records = jsonDecode(raw) as List<dynamic>;

    final exercises = <ExercisesCompanion>[];
    final instructions = <ExerciseInstructionsCompanion>[];

    for (final item in records.cast<Map<String, dynamic>>()) {
      final id = item['id'] as String;
      final secondary = item['secondary_muscles'] as List<dynamic>?;

      exercises.add(
        ExercisesCompanion.insert(
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
        ),
      );

      final steps =
          (item['instruction_steps'] as Map<String, dynamic>?) ?? const {};
      steps.forEach((language, rawSteps) {
        final list = (rawSteps as List<dynamic>).cast<String>();
        for (var i = 0; i < list.length; i++) {
          instructions.add(
            ExerciseInstructionsCompanion.insert(
              exerciseId: id,
              language: language,
              stepNumber: i + 1,
              instruction: list[i],
            ),
          );
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
  Future<List<Exercise>> searchExercises(String query) async {
    return (await searchPage(query: query)).exercises;
  }

  /// Un ejercicio por su id, para resolver las referencias de las metas
  /// (spec 005).
  Future<Exercise?> exerciseById(String id) async {
    final localUserId = await _localUserId();
    final exercise = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.equals(id) & _visible(localUserId))).getSingleOrNull();
    if (exercise == null) return null;
    final preferences = await _preferencesFor([id], localUserId);
    return _projectExercise(exercise, preferences[id]);
  }

  /// Ejercicios por lote de ids (RF-3 de la 014): devuelve solo los pedidos,
  /// tolera ids desconocidos/duplicados con una sola consulta `isIn`.
  Future<Map<String, Exercise>> exercisesByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final localUserId = await _localUserId();
    final uniqueIds = ids.toSet().toList();
    final rows = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.isIn(uniqueIds) & _visible(localUserId))).get();
    final preferences = await _preferencesFor(uniqueIds, localUserId);
    return {
      for (final row in rows)
        row.id: _projectExercise(row, preferences[row.id]),
    };
  }

  /// Nombre por id de ejercicio, para las tarjetas del dashboard de metas.
  Future<Map<String, String>> exerciseNames() async {
    final localUserId = await _localUserId();
    final rows =
        await (_db.selectOnly(_db.exercises)
              ..addColumns([_db.exercises.id, _db.exercises.name])
              ..where(_visible(localUserId)))
            .get();
    return {
      for (final row in rows)
        row.read(_db.exercises.id)!: row.read(_db.exercises.name)!,
    };
  }

  void invalidateFilterOptions() {
    _filterOptionsCache = null;
    _filterOptionsCacheOwner = null;
  }

  Stream<List<Exercise>> watchVisibleExercises() async* {
    final localUserId = await _localUserId();
    final query = _db.select(_db.exercises)
      ..where((t) => _visible(localUserId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.name),
        (t) => OrderingTerm.asc(t.id),
      ]);
    yield* query.watch().map((rows) {
      _filterOptionsCache = null;
      return rows;
    });
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
    final localUserId = await _localUserId();
    final predicate = _searchPredicate(query, filter, localUserId);
    final count = _db.exercises.id.count();
    final total =
        await (_db.selectOnly(_db.exercises)
              ..addColumns([count])
              ..where(predicate))
            .getSingle()
            .then((row) => row.read(count) ?? 0);
    final exercises =
        await (_db.select(_db.exercises)
              ..where((t) => predicate)
              ..orderBy([
                (t) => OrderingTerm.asc(t.name),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize, offset: offset))
            .get();
    final preferences = await _preferencesFor(
      exercises.map((exercise) => exercise.id).toList(),
      localUserId,
    );
    return (
      exercises: [
        for (final exercise in exercises)
          _projectExercise(exercise, preferences[exercise.id]),
      ],
      total: total,
    );
  }

  /// Valores disponibles por dimensión (RF-3 de la 003), leídos de la base
  /// local; `secondary_muscles` se extrae del JSON de cada fila porque es
  /// una lista por ejercicio.
  Future<FilterOptions> filterOptions() async {
    final localUserId = await _localUserId();
    final cached = _filterOptionsCache;
    if (cached != null && _filterOptionsCacheOwner == localUserId) {
      return cached;
    }

    Future<List<String>> distinct(GeneratedColumn<String> column) async {
      final rows =
          await (_db.selectOnly(_db.exercises, distinct: true)
                ..addColumns([column])
                ..where(_visible(localUserId))
                ..orderBy([OrderingTerm.asc(column)]))
              .get();
      return [for (final row in rows) row.read(column)!];
    }

    final secondary = <String>{};
    final column = _db.exercises.secondaryMuscles;
    final rows =
        await (_db.selectOnly(_db.exercises)
              ..addColumns([column])
              ..where(_visible(localUserId)))
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
    _filterOptionsCacheOwner = localUserId;
    return options;
  }

  /// Grupos musculares disponibles, para las metas de volumen por músculo
  /// (spec 005, RF-1).
  Future<List<String>> muscleGroups() async {
    final localUserId = await _localUserId();
    return await (_db.selectOnly(_db.exercises, distinct: true)
          ..addColumns([_db.exercises.muscleGroup])
          ..where(_visible(localUserId))
          ..orderBy([OrderingTerm.asc(_db.exercises.muscleGroup)]))
        .map((row) => row.read(_db.exercises.muscleGroup)!)
        .get();
  }

  Expression<bool> _visible(String localUserId) {
    return _db.exercises.origin.equals('catalog') |
        _db.exercises.localUserId.equals(localUserId);
  }

  /// Predicado común para el contador (RF-4) y la página de resultados.
  Expression<bool> _searchPredicate(
    String query,
    ExerciseFilter filter,
    String localUserId,
  ) {
    final conditions = <Expression<bool>>[_visible(localUserId)];

    final normalized = normalizeSearchText(query);
    if (normalized.isNotEmpty) {
      conditions.add(
        _db.exercises.name.like(
          '%${escapeLike(normalized)}%',
          escapeChar: r'\',
        ),
      );
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
            .map(
              (name) =>
                  secondary.like('%${escapeLike(name)}%', escapeChar: r'\'),
            )
            .reduce((a, b) => a | b),
      );
    }

    return conditions.reduce((a, b) => a & b);
  }

  /// Escapa los comodines de `LIKE` (la barra, `%` y `_`) para que la
  /// búsqueda sea literal (RF-1).
  static String escapeLike(String text) =>
      text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  Future<String> _localUserId() async {
    final profile = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(1))).getSingle();
    return profile.localUserId;
  }

  Future<Map<String, ExercisePreference>> _preferencesFor(
    List<String> exerciseIds,
    String localUserId,
  ) async {
    if (exerciseIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.exercisePreferences)..where(
              (t) =>
                  t.localUserId.equals(localUserId) &
                  t.exerciseId.isIn(exerciseIds),
            ))
            .get();
    return {for (final row in rows) row.exerciseId: row};
  }

  Exercise _projectExercise(Exercise exercise, ExercisePreference? preference) {
    if (exercise.origin == 'custom') return exercise;
    return exercise.copyWith(restSeconds: preference?.restSeconds ?? 90);
  }

  Future<int> effectiveRestSeconds(String exerciseId) async {
    final localUserId = await _localUserId();
    final exercise =
        await (_db.select(_db.exercises)
              ..where((t) => t.id.equals(exerciseId) & _visible(localUserId)))
            .getSingleOrNull();
    if (exercise == null) return 90;
    if (exercise.origin == 'custom') return exercise.restSeconds;
    final preference =
        await (_db.select(_db.exercisePreferences)..where(
              (t) =>
                  t.localUserId.equals(localUserId) &
                  t.exerciseId.equals(exerciseId),
            ))
            .getSingleOrNull();
    return preference?.restSeconds ?? 90;
  }

  Stream<int> watchEffectiveRestSeconds(String exerciseId) async* {
    final localUserId = await _localUserId();
    final query = _db.select(_db.exercises).join([
      leftOuterJoin(
        _db.exercisePreferences,
        _db.exercisePreferences.exerciseId.equalsExp(_db.exercises.id) &
            _db.exercisePreferences.localUserId.equals(localUserId),
      ),
    ])..where(_db.exercises.id.equals(exerciseId) & _visible(localUserId));
    yield* query.watchSingleOrNull().map((row) {
      if (row == null) return 90;
      final exercise = row.readTable(_db.exercises);
      if (exercise.origin == 'custom') return exercise.restSeconds;
      return row.readTableOrNull(_db.exercisePreferences)?.restSeconds ?? 90;
    });
  }

  Future<void> updateRestSeconds(String exerciseId, int seconds) async {
    if (seconds < 15 || seconds > 300) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'El descanso debe estar entre 15 y 300 segundos',
      );
    }
    await _db.transaction(() async {
      final localUserId = await _localUserId();
      final exercise =
          await (_db.select(_db.exercises)
                ..where((t) => t.id.equals(exerciseId) & _visible(localUserId)))
              .getSingle();
      if (exercise.origin == 'custom') {
        await (_db.update(_db.exercises)..where(
              (t) =>
                  t.id.equals(exerciseId) &
                  t.origin.equals('custom') &
                  t.localUserId.equals(localUserId),
            ))
            .write(
              ExercisesCompanion(
                restSeconds: Value(seconds),
                updatedAt: Value(DateTime.now()),
              ),
            );
        return;
      }
      final existing =
          await (_db.select(_db.exercisePreferences)..where(
                (t) =>
                    t.localUserId.equals(localUserId) &
                    t.exerciseId.equals(exerciseId),
              ))
              .getSingleOrNull();
      final now = DateTime.now();
      if (existing == null) {
        await _db
            .into(_db.exercisePreferences)
            .insert(
              ExercisePreferencesCompanion.insert(
                id: const Uuid().v4(),
                localUserId: localUserId,
                exerciseId: exerciseId,
                restSeconds: Value(seconds),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_db.update(
          _db.exercisePreferences,
        )..where((t) => t.id.equals(existing.id))).write(
          ExercisePreferencesCompanion(
            restSeconds: Value(seconds),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}
