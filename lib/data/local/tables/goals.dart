import 'package:drift/drift.dart';

/// Meta del usuario (spec 005, RF-1/RF-2): tipo, objetivo, plazo y estado.
class Goals extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get localUserId => text()(); // UUID
  TextColumn get type => text()(); // bodyweight, strength, volume, consistency
  RealColumn get targetValue => real()();
  DateTimeColumn get deadline => dateTime().nullable()();
  // Para volume: weekly | monthly; el resto de tipos lo dejan null.
  TextColumn get period => text().nullable()();
  // exercise_id (strength/volume) o muscle_group (volume).
  TextColumn get metricRef => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, achieved, abandoned
  // Progreso recalculado al cerrar sesión y al sincronizar (RF-3).
  RealColumn get currentValue => real().nullable()();
  // Punto de partida de una meta de peso (pérdida): solo local, se descarta
  // en el payload remoto (RF-13). Coincide con el peso registrado al crearla.
  RealColumn get baselineValue => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}