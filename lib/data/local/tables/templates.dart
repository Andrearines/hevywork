import 'package:drift/drift.dart';

/// Cache local del catálogo de plantillas comunitarias (spec 010, RF-3).
/// Es contenido público de solo lectura: se refresca desde Postgres y
/// permite navegar sin conexión tras la primera carga.
@DataClassName('CommunityTemplate')
class Templates extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get level => text().nullable()();
  TextColumn get goal => text().nullable()();
  IntColumn get targetDays => integer().nullable()(); // Días/semana
  IntColumn get weeks => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Día de una plantilla (spec 010): una plantilla de un solo día importa una
/// rutina; un programa de varios días importa una rutina por día.
@DataClassName('TemplateDay')
class TemplateDays extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text().references(Templates, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {templateId, orderIndex},
  ];
}

@DataClassName('TemplateExercise')
class TemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text().references(TemplateDays, #id)();
  // Sin clave foránea al catálogo: un ejercicio puede desaparecer y la
  // importación lo omite avisando (caso límite de la 010).
  TextColumn get exerciseId => text()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {dayId, orderIndex},
  ];
}

@DataClassName('TemplateSet')
class TemplateSets extends Table {
  TextColumn get id => text()();
  TextColumn get templateExerciseId =>
      text().references(TemplateExercises, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get setType => text().withDefault(const Constant('normal'))();
  RealColumn get weightKg => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get rir => integer().withDefault(const Constant(0))();
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {templateExerciseId, orderIndex},
  ];
}
