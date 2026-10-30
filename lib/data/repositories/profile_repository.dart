import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/data_export.dart';
import '../../domain/profile_stats.dart';
import '../local/database.dart';
import 'workout_repository.dart' show MutationEnqueuer;

class ProfileRepository {
  final AppDatabase _db;
  final MutationEnqueuer? enqueue;

  ProfileRepository(this._db, {this.enqueue});

  Stream<LocalProfile> watchProfile() => (_db.select(
    _db.localProfiles,
  )..where((t) => t.id.equals(1))).watchSingle();

  Future<LocalProfile> _profile() async =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();

  /// Perfil actual para precargar diálogos de ajustes.
  Future<LocalProfile> current() => _profile();

  Future<void> setDisplayName(String? name) async {
    final trimmed = name?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(displayName: Value(value)),
    );
    await _enqueueProfile();
  }

  Future<void> setUnitSystem(String unitSystem) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(unitSystem: Value(unitSystem)),
    );
    await _enqueueProfile();
  }

  Future<String> currentUnitSystem() async => (await _profile()).unitSystem;

  Future<void> setPreferRpe(bool value) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(preferRpe: Value(value)),
    );
  }

  /// Sexo para la estimación US Navy (spec 009, RF-4): `male`/`female`.
  Future<void> setSex(String? value) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(sex: Value(value)),
    );
    await _enqueueProfile();
  }

  /// Altura en cm (base); null borra el dato.
  Future<void> setHeightCm(double? value) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(heightCm: Value(value)),
    );
    await _enqueueProfile();
  }

  /// URL del avatar (foto de perfil). `null` borra la foto.
  Future<void> setAvatarUrl(String? url) async {
    await (_db.update(_db.localProfiles)..where((t) => t.id.equals(1))).write(
      LocalProfilesCompanion(avatarUrl: Value(url)),
    );
    await _enqueueProfile();
  }

  Future<void> _enqueueProfile() async {
    final profile = await _profile();
    final payload = <String, dynamic>{
      'display_name': profile.displayName,
      'unit_system': profile.unitSystem,
      'sex': profile.sex,
      'height_cm': profile.heightCm,
      'avatar_url': profile.avatarUrl,
    };
    await enqueue?.call('upsert', 'profiles', jsonEncode(payload));
  }

  Stream<ProfileStats> watchStats() {
    final query = _db.select(_db.workoutSets).join([
      innerJoin(
        _db.workoutExercises,
        _db.workoutExercises.id.equalsExp(_db.workoutSets.workoutExerciseId),
      ),
      innerJoin(
        _db.workouts,
        _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
      ),
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
      ),
    ])
      ..where(_db.workouts.status.equals('finished'))
      ..where(_db.workoutSets.completed.equals(true));

    return query.watch().map((rows) {
      final workoutIds = <String>{};
      final ends = <DateTime>[];
      final sets = <LoggedSet>[];
      for (final row in rows) {
        final workout = row.readTable(_db.workouts);
        final exercise = row.readTable(_db.exercises);
        final set = row.readTable(_db.workoutSets);
        workoutIds.add(workout.id);
        if (workout.endedAt != null) ends.add(workout.endedAt!);
        sets.add(
          LoggedSet(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            setType: set.setType,
            weightKg: set.weightKg,
            reps: set.reps,
            rir: set.rir ?? 0,
            completed: set.completed,
            endedAt: workout.endedAt,
          ),
        );
      }
      return ProfileStats(
        finishedSessions: workoutIds.length,
        totalVolumeKg: totalVolumeKg(sets),
        weekStreak: weekStreak(ends, DateTime.now()),
        records: personalRecords(sets),
      );
    });
  }

  Future<String> exportCsv() async {
    final workouts = await (_db.select(
      _db.workouts,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).get();
    final metrics = await (_db.select(
      _db.bodyMetrics,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
    return buildExportCsv(
      workouts: [
        for (final workout in workouts)
          (
            id: workout.id,
            name: workout.name,
            status: workout.status,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
          ),
      ],
      metrics: [
        for (final metric in metrics)
          (
            date: metric.date,
            weightKg: metric.weightKg,
            measuresJson: metric.measuresJson,
            notes: metric.notes,
          ),
      ],
    );
  }
}
