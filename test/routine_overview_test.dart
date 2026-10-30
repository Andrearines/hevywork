import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/routine_overview.dart';

void main() {
  group('focusOfExercise (RF-20)', () {
    test('clasifica por grupo muscular', () {
      expect(
        focusOfExercise(muscleGroup: 'chest', target: 'pectorals'),
        SessionFocus.push,
      );
      expect(
        focusOfExercise(muscleGroup: 'triceps', target: 'triceps'),
        SessionFocus.push,
      );
      expect(
        focusOfExercise(muscleGroup: 'biceps', target: 'biceps'),
        SessionFocus.pull,
      );
      expect(
        focusOfExercise(muscleGroup: 'latissimus dorsi', target: 'lats'),
        SessionFocus.pull,
      );
      expect(
        focusOfExercise(muscleGroup: 'quadriceps', target: 'quads'),
        SessionFocus.legs,
      );
      expect(
        focusOfExercise(muscleGroup: 'calves', target: 'calves'),
        SessionFocus.legs,
      );
      expect(
        focusOfExercise(muscleGroup: 'abs', target: 'abs'),
        SessionFocus.core,
      );
    });

    test('normaliza claves con espacios y mayúsculas', () {
      expect(
        focusOfExercise(muscleGroup: 'Rotator Cuff', target: 'delts'),
        SessionFocus.push,
      );
      expect(
        focusOfExercise(muscleGroup: 'Lower Back', target: 'spine'),
        SessionFocus.pull,
      );
    });

    test('usa el objetivo como respaldo y Core para lo desconocido', () {
      expect(
        focusOfExercise(muscleGroup: 'desconocido', target: 'quads'),
        SessionFocus.legs,
      );
      expect(
        focusOfExercise(muscleGroup: 'desconocido'),
        SessionFocus.core,
      );
    });
  });

  group('muscleTargetLabel', () {
    test('traduce los objetivos del catálogo y deja el resto tal cual', () {
      expect(muscleTargetLabel('pectorals'), 'Pecho');
      expect(muscleTargetLabel('upper back'), 'Espalda alta');
      expect(muscleTargetLabel('delts'), 'Hombros');
      expect(muscleTargetLabel('custom muscle'), 'custom muscle');
    });
  });

  group('buildSessionBreakdown (RF-20)', () {
    final exercises = [
      (muscleGroup: 'chest', target: 'pectorals'),
      (muscleGroup: 'triceps', target: 'triceps'),
      (muscleGroup: 'biceps', target: 'biceps'),
      (muscleGroup: 'abs', target: 'abs'),
    ];

    test('agrupa por enfoque en orden de aparición', () {
      final rows = buildSessionBreakdown(
        exercises: exercises,
        targetDays: 6,
        today: DateTime(2026, 10, 7), // miércoles
      );

      expect(rows, hasLength(3));
      expect(rows[0].title, 'Empuje');
      expect(rows[0].muscles, 'Pecho, Tríceps');
      expect(rows[0].exerciseCount, 2);
      expect(rows[0].detail, 'Pecho, Tríceps · 2 ejercicios');
      expect(rows[1].title, 'Tracción');
      expect(rows[1].exerciseCount, 1);
      expect(rows[2].title, 'Core');
    });

    test('reparte los días según la frecuencia (paso = 7 / días)', () {
      final rows = buildSessionBreakdown(
        exercises: exercises,
        targetDays: 6,
        today: DateTime(2026, 10, 7), // miércoles
      );
      expect(rows[0].dayLabel, 'Hoy');
      expect(rows[1].dayLabel, 'Mañana');
      expect(rows[2].dayLabel, 'Viernes');

      final everyOther = buildSessionBreakdown(
        exercises: exercises,
        targetDays: 2,
        today: DateTime(2026, 10, 7), // miércoles
      );
      expect(everyOther[0].dayLabel, 'Hoy');
      expect(everyOther[1].dayLabel, 'Sábado');
      expect(everyOther[2].dayLabel, 'Martes');
    });

    test('sin frecuencia asigna días consecutivos y vacío devuelve nada', () {
      final rows = buildSessionBreakdown(
        exercises: exercises,
        today: DateTime(2026, 10, 7),
      );
      expect(rows[0].dayLabel, 'Hoy');
      expect(rows[1].dayLabel, 'Mañana');

      expect(
        buildSessionBreakdown(exercises: const [], today: DateTime(2026)),
        isEmpty,
      );
    });
  });

  group('métricas derivadas de las tarjetas', () {
    test('avgSetsPerSession reparte las series entre los ejercicios', () {
      expect(avgSetsPerSession(totalSets: 22, exerciseCount: 11), 2);
      expect(avgSetsPerSession(totalSets: 5, exerciseCount: 2), 2);
      expect(avgSetsPerSession(totalSets: 0, exerciseCount: 3), 0);
      expect(avgSetsPerSession(totalSets: 5, exerciseCount: 0), 0);
    });

    test('rirRangeLabel muestra rango o valor único', () {
      expect(rirRangeLabel(1, 2), 'RIR 1 - 2');
      expect(rirRangeLabel(2, 2), 'RIR 2');
      expect(rirRangeLabel(null, 2), isNull);
    });

    test('lastUsedFooter traduce el tiempo transcurrido', () {
      final now = DateTime(2026, 10, 7, 12);
      expect(lastUsedFooter(now, now: now), 'Último uso hoy');
      expect(
        lastUsedFooter(now.subtract(const Duration(days: 1)), now: now),
        'Último uso hace 1 día',
      );
      expect(
        lastUsedFooter(now.subtract(const Duration(days: 12)), now: now),
        'Último uso hace 12 días',
      );
      expect(
        lastUsedFooter(now.subtract(const Duration(days: 30)), now: now),
        'Último uso hace 1 mes',
      );
      expect(
        lastUsedFooter(now.subtract(const Duration(days: 45)), now: now),
        'Último uso hace 2 meses',
      );
    });

    test('normalizeCategory equipara lo guardado con las claves de filtro', () {
      expect(normalizeCategory('PPL'), 'ppl');
      expect(normalizeCategory('Torso / Pierna'), 'torsopierna');
      expect(normalizeCategory('Torso-Pierna'), 'torsopierna');
      expect(normalizeCategory('Fuerza'), 'fuerza');
      expect(normalizeCategory(null), '');
    });
  });
}
