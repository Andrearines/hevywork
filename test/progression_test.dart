import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/progression.dart';

void main() {
  const normal = (reps: 8, rir: 2, setType: 'normal');
  const warmup = (reps: 8, rir: 2, setType: 'warmup');

  group('progressionGoalMet (RF-3)', () {
    test('cumple con el objetivo exacto', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [normal, normal, normal],
        ),
        isTrue,
      );
    });

    test('rechaza si faltan series completadas', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [normal, normal],
        ),
        isFalse,
      );
    });

    test('rechaza si alguna serie baja de repeticiones', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [
            normal,
            (reps: 6, rir: 2, setType: 'normal'),
            normal,
          ],
        ),
        isFalse,
      );
    });

    test('rechaza si alguna serie supera el RIR objetivo', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [
            normal,
            (reps: 8, rir: 4, setType: 'normal'),
            normal,
          ],
        ),
        isFalse,
      );
    });

    test('ignora los calentamientos al contar las series', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [warmup, normal, normal, normal],
        ),
        isTrue,
      );
    });

    test('las series extra no evaluadas no rompen el objetivo', () {
      expect(
        progressionGoalMet(
          targetSets: 3,
          targetReps: 8,
          targetRir: 2,
          completedSets: [
            normal,
            normal,
            normal,
            (reps: 5, rir: 3, setType: 'normal'),
            (reps: 4, rir: 3, setType: 'drop'),
          ],
        ),
        isTrue,
      );
    });
  });

  group('nextSuggestedWeight', () {
    test('suma el incremento por defecto', () {
      expect(nextSuggestedWeight(60), 62.5);
    });

    test('redondea a 0.001 kg', () {
      expect(nextSuggestedWeight(60.0004), 62.5);
      expect(nextSuggestedWeight(60.0009), 62.501);
    });
  });
}