import '../../data/local/database.dart';

class WorkoutManager {
  /// Calcula el e1RM usando la fórmula: weight_kg × (1 + (reps + RIR)/30)
  /// Solo es válido si reps <= 12.
  /// Si reps == 1 y RIR == 0, e1RM = weight_kg.
  double? calculateE1RM(double weightKg, int reps, int rir) {
    if (reps > 12 || weightKg <= 0 || reps <= 0) return null;
    if (reps == 1 && rir == 0) return weightKg;
    
    return weightKg * (1 + (reps + rir) / 30);
  }

  /// Computa el volumen de la sesión.
  /// Excluye warmup.
  /// Dropsets valen 50%.
  double computeVolume(List<WorkoutSet> sets) {
    double totalVolume = 0.0;
    for (final s in sets) {
      if (s.setType == 'warmup' || !s.completed) continue;
      
      double volume = s.weightKg * s.reps;
      if (s.setType == 'drop') {
        volume = volume * 0.5;
      }
      totalVolume += volume;
    }
    return totalVolume;
  }
}
