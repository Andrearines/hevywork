import 'package:drift/drift.dart';
import 'exercises.dart';

class Workouts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get localUserId => text()(); // UUID
  TextColumn get routineId => text().nullable()(); // UUID, null if free workout
  TextColumn get name => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, finished, abandoned
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Temporizador de descanso local (RF-5 a RF-8 de la 002): es estado de UI
  // por dispositivo y no viaja al remoto (la whitelist de RF-13 lo descarta).
  DateTimeColumn get restEndsAt => dateTime().nullable()();
  IntColumn get restPausedSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutExercises extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetRir => integer().nullable()();
  RealColumn get suggestedWeightKg => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [{workoutId, orderIndex}];
}

class WorkoutSets extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get workoutExerciseId => text().references(WorkoutExercises, #id)();
  // Serie planificada de la rutina que originó esta serie (RF-2/RF-4): permite
  // persistir en la rutina los valores reales registrados en la sesión. Null
  // en sesiones libres o series añadidas en vivo.
  TextColumn get routineSetId => text().nullable()();
  IntColumn get orderIndex => integer()();
  TextColumn get setType => text().withDefault(const Constant('normal'))(); // warmup, normal, failure, drop
  RealColumn get weightKg => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get rir => integer().nullable()();
  // Descanso planificado de la serie (RF-1 de la 004); null usa el del
  // ejercicio. Es un valor de plantilla, no estado del temporizador.
  IntColumn get restSeconds => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
