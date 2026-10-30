import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/goals.dart';
import '../local/database.dart';
import 'workout_repository.dart' show MutationEnqueuer;

/// Metas (spec 005): CRUD, registro de peso corporal y recálculo de progreso
/// (RF-3). Cada escritura local se encola para sincronizar (RF-11).
class GoalRepository {
  final AppDatabase _db;
  final MutationEnqueuer? enqueue;

  GoalRepository(this._db, {this.enqueue});

  Stream<List<Goal>> watchGoals() => (_db.select(_db.goals)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  /// Crea una meta activa (RF-2). Para `bodyweight` fija el punto de partida
  /// en el último peso registrado, si lo hay.
  Future<Goal> createGoal({
    required String type,
    required double targetValue,
    DateTime? deadline,
    String? period,
    String? metricRef,
  }) async {
    _validate(
      type: type,
      targetValue: targetValue,
      deadline: deadline,
      period: period,
      metricRef: metricRef,
    );
    final now = DateTime.now();
    final profile = await _profile();
    final baseline = type == 'bodyweight' ? await _latestWeightKg() : null;
    final goal = Goal(
      id: const Uuid().v4(),
      localUserId: profile.localUserId,
      type: type,
      targetValue: targetValue,
      deadline: deadline,
      period: period,
      metricRef: metricRef,
      status: 'active',
      currentValue: null,
      baselineValue: baseline,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.goals).insert(goal);
    await _enqueueRow('upsert', 'goals', _goalPayload(goal));
    return goal;
  }

  /// Edita una meta: reactiva el seguimiento (pasa a `active`) y refresca el
  /// punto de partida en las metas de peso.
  Future<Goal> updateGoal(
    String id, {
    required String type,
    required double targetValue,
    DateTime? deadline,
    String? period,
    String? metricRef,
  }) async {
    _validate(
      type: type,
      targetValue: targetValue,
      deadline: deadline,
      period: period,
      metricRef: metricRef,
    );
    final existing = await (_db.select(_db.goals)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) throw ArgumentError('Meta no encontrada: $id');

    final now = DateTime.now();
    final baseline = type == 'bodyweight' ? await _latestWeightKg() : null;
    final updated = existing.copyWith(
      type: type,
      targetValue: targetValue,
      deadline: Value(deadline),
      period: Value(period),
      metricRef: Value(metricRef),
      status: 'active',
      currentValue: const Value(null),
      baselineValue: Value(baseline),
      updatedAt: now,
    );
    await _db.update(_db.goals).replace(updated);
    await _enqueueRow('upsert', 'goals', _goalPayload(updated));
    return updated;
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goals)..where((t) => t.id.equals(id))).go();
    await _enqueueRow('delete', 'goals', {'id': id});
  }

  /// Recalcula el progreso de todas las metas (RF-3) y devuelve las que han
  /// pasado a `achieved` en esta pasada. Evaluación en caliente: las metas
  /// `achieved`/`abandoned` no cambian.
  Future<List<Goal>> recalculate({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final goals = await (_db.select(_db.goals)).get();
    if (goals.isEmpty) return const [];

    final since30 = clock.subtract(const Duration(days: kVolumeMonthDays));
    final since7 = clock.subtract(const Duration(days: kConsistencyWindowDays));

    final workouts = await (_db.select(_db.workouts)
          ..where((t) =>
              t.status.equals('finished') & t.endedAt.isBiggerOrEqualValue(since30)))
        .get();
    final workoutIds = [for (final w in workouts) w.id];
    final endedByWorkout = {for (final w in workouts) w.id: w.endedAt};
    final finishedEndedAts = [
      for (final w in workouts)
        if (w.endedAt != null &&
            !w.endedAt!.isBefore(since7) &&
            !w.endedAt!.isAfter(clock))
          w.endedAt!,
    ];

    final items = <WorkoutExercise>[];
    final muscleByItem = <String, String>{};
    if (workoutIds.isNotEmpty) {
      final joined = await (_db.select(_db.workoutExercises).join([
        innerJoin(
          _db.workouts,
          _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
        ),
        innerJoin(
          _db.exercises,
          _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
        ),
      ])
            ..where(_db.workouts.id.isIn(workoutIds)))
          .get();
      for (final row in joined) {
        final item = row.readTable(_db.workoutExercises);
        items.add(item);
        muscleByItem[item.id] = row.readTable(_db.exercises).muscleGroup;
      }
    }

    final itemIds = [for (final item in items) item.id];
    final setsByItem = <String, List<WorkoutSet>>{};
    if (itemIds.isNotEmpty) {
      final rows = await (_db.select(_db.workoutSets)
            ..where((t) => t.workoutExerciseId.isIn(itemIds)))
          .get();
      for (final set in rows) {
        setsByItem.putIfAbsent(set.workoutExerciseId, () => []).add(set);
      }
    }

    final weights = await (_db.select(_db.bodyMetrics)).get();

    final strengthByExercise = <String, double?>{};
    for (final goal in goals) {
      if (goal.type == 'strength' && goal.metricRef != null) {
        strengthByExercise[goal.metricRef!] =
            await _strengthBest(goal.metricRef!);
      }
    }

    final achieved = <Goal>[];
    await _db.transaction(() async {
      for (final goal in goals) {
        final double? current = switch (goal.type) {
          'bodyweight' => latestBodyWeight([
              for (final w in weights)
                (weightKg: w.weightKg, measuredAt: w.date),
            ]),
          'strength' => strengthByExercise[goal.metricRef],
          'consistency' =>
            consistencySessions(finishedEndedAts, clock).toDouble(),
          'volume' => _volumeCurrent(
              goal,
              items,
              muscleByItem,
              setsByItem,
              endedByWorkout,
              clock,
            ),
          _ => null,
        };
        final status = evaluateGoalStatus(
          currentStatus: goal.status,
          type: goal.type,
          currentValue: current,
          targetValue: goal.targetValue,
          startValue: goal.baselineValue,
          deadline: goal.deadline,
          now: clock,
        );
        if (current == goal.currentValue && status == goal.status) continue;
        final updated = goal.copyWith(
          currentValue: Value(current),
          status: status,
          updatedAt: clock,
        );
        await _db.update(_db.goals).replace(updated);
        await _enqueueRow('upsert', 'goals', _goalPayload(updated));
        if (goal.status == 'active' && status == 'achieved') {
          achieved.add(updated);
        }
      }
    });
    return achieved;
  }

  /// Volumen acumulado de la meta en su ventana (semanal o mensual), con el
  /// mismo criterio de WorkoutManager (sin calentamientos, drops al 50 %).
  double _volumeCurrent(
    Goal goal,
    List<WorkoutExercise> items,
    Map<String, String> muscleByItem,
    Map<String, List<WorkoutSet>> setsByItem,
    Map<String, DateTime?> endedByWorkout,
    DateTime clock,
  ) {
    final ref = goal.metricRef;
    if (ref == null) return 0;
    final days =
        goal.period == 'weekly' ? kVolumeWeekDays : kVolumeMonthDays;
    final since = clock.subtract(Duration(days: days));
    var total = 0.0;
    for (final item in items) {
      final endedAt = endedByWorkout[item.workoutId];
      if (endedAt == null || endedAt.isBefore(since)) continue;
      if (item.exerciseId != ref && muscleByItem[item.id] != ref) continue;
      for (final set in setsByItem[item.id] ?? const <WorkoutSet>[]) {
        total += setVolumeKg(
          weightKg: set.weightKg,
          reps: set.reps,
          setType: set.setType,
          completed: set.completed,
        );
      }
    }
    return total;
  }

  Future<double?> _strengthBest(String exerciseId) async {
    final rows = await (_db.select(_db.workoutSets).join([
      innerJoin(
        _db.workoutExercises,
        _db.workoutExercises.id.equalsExp(_db.workoutSets.workoutExerciseId),
      ),
    ])
          ..where(_db.workoutExercises.exerciseId.equals(exerciseId) &
              _db.workoutSets.completed.equals(true)))
        .get();
    double? best;
    for (final row in rows) {
      final set = row.readTable(_db.workoutSets);
      if (set.setType == 'warmup') continue;
      final e = e1RM(weightKg: set.weightKg, reps: set.reps, rir: set.rir ?? 0);
      if (e != null && (best == null || e > best)) best = e;
    }
    return best;
  }

  void _validate({
    required String type,
    required double targetValue,
    DateTime? deadline,
    String? period,
    String? metricRef,
  }) {
    if (!kGoalTypes.contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
    if (targetValue <= 0) throw ArgumentError.value(targetValue, 'targetValue');
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      throw ArgumentError.value(deadline, 'deadline');
    }
    if (type == 'volume') {
      if (period != 'weekly' && period != 'monthly') {
        throw ArgumentError.value(period, 'period');
      }
      if (metricRef == null || metricRef.isEmpty) {
        throw ArgumentError.value(metricRef, 'metricRef');
      }
    }
    if (type == 'strength' && (metricRef == null || metricRef.isEmpty)) {
      throw ArgumentError.value(metricRef, 'metricRef');
    }
    if ((type == 'bodyweight' || type == 'consistency') && metricRef != null) {
      throw ArgumentError.value(metricRef, 'metricRef');
    }
  }

  Map<String, dynamic> _goalPayload(Goal goal) => {
        'id': goal.id,
        'type': goal.type,
        'target_value': goal.targetValue,
        if (goal.deadline != null) 'deadline': goal.deadline!.toIso8601String(),
        if (goal.period != null) 'period': goal.period,
        if (goal.metricRef != null) 'metric_ref': goal.metricRef,
        'status': goal.status,
        if (goal.currentValue != null) 'current_value': goal.currentValue,
      };

  /// Último peso registrado (baseline de las metas de peso); solo lectura.
  Future<double?> _latestWeightKg() async {
    final row = await (_db.select(_db.bodyMetrics)
          ..where((t) => t.weightKg.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
    return row?.weightKg;
  }

  Future<LocalProfile> _profile() async =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _enqueueRow(
    String operation,
    String table,
    Map<String, dynamic> payload,
  ) async {
    await enqueue?.call(operation, table, jsonEncode(payload));
  }
}