import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/goals.dart';

void main() {
  group('e1RM', () {
    test('calcula weight × (1 + (reps + rir)/30)', () {
      expect(
        e1RM(weightKg: 100, reps: 5, rir: 2),
        closeTo(100 * (1 + 7 / 30), 1e-9),
      );
    });

    test('reps > 12 no tiene e1RM', () {
      expect(e1RM(weightKg: 100, reps: 13, rir: 2), isNull);
    });

    test('reps == 1 y rir == 0 vale el peso', () {
      expect(e1RM(weightKg: 120, reps: 1, rir: 0), 120);
    });

    test('peso o reps sin sentido no dan e1RM', () {
      expect(e1RM(weightKg: 0, reps: 5, rir: 2), isNull);
      expect(e1RM(weightKg: -10, reps: 5, rir: 2), isNull);
      expect(e1RM(weightKg: 60, reps: 0, rir: 0), isNull);
    });
  });

  group('setVolumeKg', () {
    test('serie normal completa suma peso × reps', () {
      expect(
        setVolumeKg(weightKg: 60, reps: 10, setType: 'normal', completed: true),
        600,
      );
    });

    test('calentamientos y series sin completar no suman', () {
      expect(
        setVolumeKg(weightKg: 60, reps: 10, setType: 'warmup', completed: true),
        0,
      );
      expect(
        setVolumeKg(
          weightKg: 60,
          reps: 10,
          setType: 'normal',
          completed: false,
        ),
        0,
      );
    });

    test('dropsets valen el 50 %', () {
      expect(
        setVolumeKg(weightKg: 60, reps: 10, setType: 'drop', completed: true),
        300,
      );
    });
  });

  group('strengthBest', () {
    test('devuelve el máximo de los valores', () {
      expect(strengthBest([70.5, 82.0, 76.0]), 82.0);
    });

    test('lista vacía devuelve null', () {
      expect(strengthBest(const []), isNull);
    });
  });

  group('consistencySessions (decisión: ventana móvil de 7 días)', () {
    final now = DateTime(2026, 10, 8, 12);

    test('cuenta las sesiones de los últimos 7 días', () {
      expect(
        consistencySessions([
          DateTime(2026, 10, 2, 9), // hace 6 días
          DateTime(2026, 10, 7, 20), // ayer
          DateTime(2026, 10, 8, 11),
        ], now),
        3,
      );
    });

    test('ignora las sesiones anteriores a la ventana y las futuras', () {
      expect(
        consistencySessions([
          DateTime(2026, 9, 25), // fuera
          DateTime(2026, 10, 1, 12), // hace exactamente 7 días
          DateTime(2026, 10, 9), // futura
        ], now),
        1,
      );
    });

    test('sin sesiones cuenta cero', () {
      expect(consistencySessions(const [], now), 0);
    });
  });

  group('latestBodyWeight', () {
    test('devuelve el peso de la medición más reciente', () {
      expect(
        latestBodyWeight([
          (weightKg: 85.0, measuredAt: DateTime(2026, 10, 1)),
          (weightKg: 84.2, measuredAt: DateTime(2026, 10, 5)),
          (weightKg: 83.8, measuredAt: DateTime(2026, 10, 3)),
        ]),
        84.2,
      );
    });

    test('sin mediciones devuelve null', () {
      expect(latestBodyWeight(const []), isNull);
    });

    test('ignora los registros sin peso (solo medidas)', () {
      expect(
        latestBodyWeight([
          (weightKg: null, measuredAt: DateTime(2026, 10, 2)),
          (weightKg: 84.2, measuredAt: DateTime(2026, 10, 5)),
          (weightKg: null, measuredAt: DateTime(2026, 10, 6)),
        ]),
        84.2,
      );
    });
  });

  group('goalMet (RF-4)', () {
    test('subir de peso se logra alcanzando o superando el objetivo', () {
      expect(
        goalMet(
          type: 'bodyweight',
          currentValue: 82,
          targetValue: 80,
          startValue: 75,
        ),
        isTrue,
      );
      expect(
        goalMet(
          type: 'bodyweight',
          currentValue: 79.9,
          targetValue: 80,
          startValue: 75,
        ),
        isFalse,
      );
    });

    test('perder peso se logra por debajo o igual al objetivo', () {
      expect(
        goalMet(
          type: 'bodyweight',
          currentValue: 79,
          targetValue: 80,
          startValue: 90,
        ),
        isTrue,
      );
      expect(
        goalMet(
          type: 'bodyweight',
          currentValue: 80,
          targetValue: 80,
          startValue: 90,
        ),
        isTrue,
      );
      expect(
        goalMet(
          type: 'bodyweight',
          currentValue: 80.5,
          targetValue: 80,
          startValue: 90,
        ),
        isFalse,
      );
    });

    test('sin punto de partida se asume subir de peso', () {
      expect(
        goalMet(type: 'bodyweight', currentValue: 85, targetValue: 80),
        isTrue,
      );
      expect(
        goalMet(type: 'bodyweight', currentValue: 79, targetValue: 80),
        isFalse,
      );
    });

    test('sin valor actual nunca se logra', () {
      expect(
        goalMet(type: 'strength', currentValue: null, targetValue: 80),
        isFalse,
      );
    });

    test('el resto de tipos se logran por encima o igual', () {
      expect(
        goalMet(type: 'strength', currentValue: 82, targetValue: 80),
        isTrue,
      );
      expect(
        goalMet(type: 'consistency', currentValue: 4, targetValue: 4),
        isTrue,
      );
      expect(
        goalMet(type: 'volume', currentValue: 19.5, targetValue: 20),
        isFalse,
      );
    });
  });

  group('goalProgress', () {
    test('progreso relativo al objetivo en metas de crecimiento', () {
      expect(
        goalProgress(
          type: 'strength',
          currentValue: 80,
          targetValue: 100,
        ),
        closeTo(0.8, 1e-9),
      );
      expect(
        goalProgress(
          type: 'strength',
          currentValue: 110,
          targetValue: 100,
        ),
        1,
      );
    });

    test('sin valor actual el progreso es cero', () {
      expect(
        goalProgress(
          type: 'strength',
          currentValue: null,
          targetValue: 100,
        ),
        0,
      );
    });

    test('pérdida de peso cierra la brecha desde el punto de partida', () {
      expect(
        goalProgress(
          type: 'bodyweight',
          currentValue: 85,
          targetValue: 80,
          startValue: 90,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(
        goalProgress(
          type: 'bodyweight',
          currentValue: 79,
          targetValue: 80,
          startValue: 90,
        ),
        1,
      );
    });

    test('pérdida de peso sin punto de partida asume subir (consistente con '
        'goalMet)', () {
      expect(
        goalProgress(
          type: 'bodyweight',
          currentValue: 85,
          targetValue: 80,
        ),
        1,
      );
    });
  });

  group('evaluateGoalStatus (RF-3/RF-4)', () {
    final now = DateTime(2026, 10, 8);

    test('sin lograr y sin plazo sigue active', () {
      expect(
        evaluateGoalStatus(
          currentStatus: 'active',
          type: 'strength',
          currentValue: 70,
          targetValue: 80,
          deadline: null,
          now: now,
        ),
        'active',
      );
    });

    test('al lograr pasa a achieved', () {
      expect(
        evaluateGoalStatus(
          currentStatus: 'active',
          type: 'strength',
          currentValue: 82,
          targetValue: 80,
          deadline: DateTime(2026, 12, 31),
          now: now,
        ),
        'achieved',
      );
    });

    test('plazo pasado sin lograr pasa a abandoned', () {
      expect(
        evaluateGoalStatus(
          currentStatus: 'active',
          type: 'strength',
          currentValue: 70,
          targetValue: 80,
          deadline: DateTime(2026, 9, 30),
          now: now,
        ),
        'abandoned',
      );
    });

    test('plazo justo en el límite (hoy) abandona si no se logró', () {
      expect(
        evaluateGoalStatus(
          currentStatus: 'active',
          type: 'strength',
          currentValue: 70,
          targetValue: 80,
          deadline: DateTime(2026, 10, 8, 0, 0),
          now: now,
        ),
        'abandoned',
      );
    });

    test('achieved y abandoned son definitivos', () {
      expect(
        evaluateGoalStatus(
          currentStatus: 'achieved',
          type: 'strength',
          currentValue: 70,
          targetValue: 80,
          deadline: null,
          now: now,
        ),
        'achieved',
      );
      expect(
        evaluateGoalStatus(
          currentStatus: 'abandoned',
          type: 'strength',
          currentValue: 90,
          targetValue: 80,
          deadline: null,
          now: now,
        ),
        'abandoned',
      );
    });
  });
}