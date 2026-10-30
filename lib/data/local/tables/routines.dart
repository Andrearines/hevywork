import 'package:drift/drift.dart';

import 'exercises.dart';

/// Plantilla de entrenamiento (spec 004, RF-1).
class Routines extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get localUserId => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  // Metadata de planificación (spec 008, T-5): nullable para que las rutinas
  // previas sigan siendo válidas sin mostrar huecos.
  TextColumn get category => text().nullable()(); // PPL, Torso-Pierna…
  TextColumn get level => text().nullable()(); // Principiante, Intermedio…
  TextColumn get goal => text().nullable()(); // Fuerza, Hipertrofia…
  IntColumn get targetDays => integer().nullable()(); // Días/semana

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ejercicio de una rutina con su progresión configurable (RF-1, RF-3).
class RoutineExercises extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get routineId => text().references(Routines, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetRir => integer().nullable()();
  RealColumn get suggestedWeightKg => real().nullable()();
  BoolColumn get autoProgress => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{routineId, orderIndex}];
}

/// Serie planificada de un ejercicio de rutina (RF-1 de la 004): tipo, peso,
/// repeticiones, RIR y descanso, una a una.
class RoutineSets extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get routineExerciseId => text().references(RoutineExercises, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get setType => text().withDefault(const Constant('normal'))();
  RealColumn get weightKg => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get rir => integer().withDefault(const Constant(0))();
  IntColumn get restSeconds => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{routineExerciseId, orderIndex}];
}