import 'package:drift/drift.dart';

import 'exercises.dart';

class ExercisePreferences extends Table {
  TextColumn get id => text()();
  TextColumn get localUserId => text()();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get restSeconds => integer().nullable().customConstraint(
        'NULL CHECK(rest_seconds IS NULL OR rest_seconds BETWEEN 15 AND 300)',
      )();
  TextColumn get target => text().nullable()();
  TextColumn get muscleGroup => text().nullable()();
  TextColumn get secondaryMuscles => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {localUserId, exerciseId},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK ((target IS NULL AND muscle_group IS NULL AND '
            'secondary_muscles IS NULL) OR (target IS NOT NULL AND '
            'muscle_group IS NOT NULL AND secondary_muscles IS NOT NULL))',
      ];
}
