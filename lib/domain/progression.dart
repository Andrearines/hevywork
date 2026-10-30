/// Incremento por defecto de la progresión automática (RF-3 de la 004).
const double kDefaultProgressionIncrementKg = 2.5;

/// Serie completada tal como la consume la evaluación de progresión.
typedef CompletedSet = ({int reps, int rir, String setType});

/// Serie planificada en la rutina tal como la consume la evaluación (RF-1).
typedef PlannedSet = ({
  String id,
  int orderIndex,
  String setType,
  double weightKg,
  int reps,
  int rir,
});

/// Decide si un ejercicio de rutina cumplió sus series objetivo (RF-3).
///
/// Criterio aprobado: al menos [targetSets] series completadas sin contar
/// los calentamientos, y cada una de las primeras [targetSets] series
/// completadas con `reps >= targetReps` y `rir <= targetRir`. Las series
/// extra sobre lo previsto no se evalúan.
bool progressionGoalMet({
  required int targetSets,
  required int targetReps,
  required int targetRir,
  required List<CompletedSet> completedSets,
}) {
  final workSets = [
    for (final set in completedSets)
      if (set.setType != 'warmup') set,
  ];
  if (workSets.length < targetSets) return false;
  return workSets
      .take(targetSets)
      .every((set) => set.reps >= targetReps && set.rir <= targetRir);
}

/// Decide si un ejercicio cumplió el objetivo evaluándolo **serie a serie**
/// (RF-3 de la 004): cada serie planificada de trabajo debe tener su serie
/// completada equivalente con `reps >= objetivo` y `rir <= objetivo`, en
/// orden y sin contar los calentamientos. Las series extra no se evalúan.
bool plannedSetsGoalMet({
  required List<PlannedSet> planned,
  required List<CompletedSet> completedSets,
}) {
  final workPlanned = [
    for (final set in planned)
      if (set.setType != 'warmup') set,
  ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  if (workPlanned.isEmpty) return false;

  final workCompleted = [
    for (final set in completedSets)
      if (set.setType != 'warmup') set,
  ];
  if (workCompleted.length < workPlanned.length) return false;

  for (var i = 0; i < workPlanned.length; i++) {
    final plan = workPlanned[i];
    final done = workCompleted[i];
    if (done.reps < plan.reps || done.rir > plan.rir) return false;
  }
  return true;
}

/// Peso sugerido para la próxima instancia (RF-3): el actual más el
/// incremento por defecto, redondeado a 0.001 kg (caso límite de la 001).
double nextSuggestedWeight(double currentKg) =>
    ((currentKg + kDefaultProgressionIncrementKg) * 1000).roundToDouble() /
    1000;
