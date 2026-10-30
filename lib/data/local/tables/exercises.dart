import 'package:drift/drift.dart';

class Exercises extends Table {
  TextColumn get id => text()(); // String ID from JSON (4 dígitos)
  TextColumn get name => text()();
  TextColumn get bodyPart => text()();
  TextColumn get equipment => text()();
  TextColumn get target => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get secondaryMuscles => text().nullable()(); // JSON array de strings
  TextColumn get mediaId => text().nullable()();
  TextColumn get imagePath => text().nullable()(); // Ruta local del dataset (images/…)
  TextColumn get gifPath => text().nullable()(); // Ruta local del dataset (videos/…)
  TextColumn get attribution => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  // Descanso por defecto tras una serie, en segundos (RF-5 de la 002):
  // rango 15–300 s, 90 s por defecto. El mismo rango lo valida
  // `CatalogRepository.updateRestSeconds` en Dart.
  IntColumn get restSeconds => integer().customConstraint(
        'NOT NULL DEFAULT 90 CHECK(rest_seconds BETWEEN 15 AND 300)',
      )();

  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseInstructions extends Table {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get language => text()(); // ISO 639-1: es, en
  IntColumn get stepNumber => integer()();
  TextColumn get instruction => text()();

  @override
  Set<Column> get primaryKey => {exerciseId, language, stepNumber};
}
