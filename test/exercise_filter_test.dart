import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/domain/exercise_filter.dart';
import 'package:hevywork/ui/widgets/exercise_filter_bar.dart';

void main() {
  group('ExerciseFilter (RF-3 de la 003)', () {
    test('vacío al construirse sin valores', () {
      const filter = ExerciseFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.activeCount, 0);
    });

    test('activeCount suma todos los valores seleccionados', () {
      const filter = ExerciseFilter(
        bodyParts: {'chest', 'shoulders'},
        equipment: {'dumbbell'},
        muscleGroups: {'chest'},
      );
      expect(filter.activeCount, 4);
      expect(filter.isEmpty, isFalse);
    });

    test('withDimension reemplaza solo la dimensión indicada', () {
      const filter = ExerciseFilter(
        equipment: {'dumbbell'},
        targets: {'biceps'},
      );
      final updated =
          filter.withDimension(ExerciseDimension.equipment, {
        'kettlebell',
        'barbell',
      });
      expect(updated.equipment, {'kettlebell', 'barbell'});
      expect(updated.targets, {'biceps'});
      // El original no se muta.
      expect(filter.equipment, {'dumbbell'});
      expect(filter.activeCount, 2);
      expect(updated.activeCount, 3);
    });

    test('valuesOf devuelve los valores de cada dimensión', () {
      const filter = ExerciseFilter(
        secondaryMuscles: {'biceps'},
        targets: {'biceps'},
      );
      expect(filter.valuesOf(ExerciseDimension.secondaryMuscle), {'biceps'});
      expect(filter.valuesOf(ExerciseDimension.target), {'biceps'});
      expect(filter.valuesOf(ExerciseDimension.bodyPart), isEmpty);
      expect(
        ExerciseFilter().withDimension(
          ExerciseDimension.muscleGroup,
          {'chest'},
        ).valuesOf(ExerciseDimension.muscleGroup),
        {'chest'},
      );
    });

    test('withDimension con conjunto vacío limpia la dimensión', () {
      const filter = ExerciseFilter(equipment: {'dumbbell'});
      final cleared = filter.withDimension(ExerciseDimension.equipment, {});
      expect(cleared.equipment, isEmpty);
      expect(cleared.isEmpty, isTrue);
    });
  });

  group('exerciseDimensionOptions fusiona sinónimos (amenda 2026-10-22)', () {
    final FilterOptions options = (
      bodyParts: ['chest'],
      equipments: ['barbell'],
      targets: ['lats', 'quads'],
      muscleGroups: ['latissimus dorsi', 'lats', 'deltoids', 'shoulders'],
      secondaryMuscles: ['groin', 'inner thighs', 'biceps'],
    );

    test('muscleFilterLabel traduce y agrupa sinónimos bajo un nombre', () {
      expect(muscleFilterLabel('quads'), 'Cuádriceps');
      expect(muscleFilterLabel('adductors'), 'Aductores');
      // Sinónimos del dataset → misma etiqueta.
      expect(muscleFilterLabel('lats'), muscleFilterLabel('latissimus dorsi'));
      expect(muscleFilterLabel('groin'), muscleFilterLabel('inner thighs'));
      expect(muscleFilterLabel('deltoids'), muscleFilterLabel('shoulders'));
      // Valor desconocido se devuelve tal cual.
      expect(muscleFilterLabel('músculo raro'), 'músculo raro');
    });

    test('muscleGroup fusiona lats/latissimus dorsi y deltoids/shoulders', () {
      final opts = exerciseDimensionOptions(
        ExerciseDimension.muscleGroup,
        options,
      );
      // 4 valores crudos → 2 etiquetas fusionadas.
      expect(opts.map((o) => o.label), ['Dorsales', 'Hombros']);
      expect(
        opts.firstWhere((o) => o.label == 'Dorsales').values,
        {'latissimus dorsi', 'lats'},
      );
      expect(
        opts.firstWhere((o) => o.label == 'Hombros').values,
        {'deltoids', 'shoulders'},
      );
    });

    test('secondaryMuscle fusiona groin/inner thighs en Aductores', () {
      final opts = exerciseDimensionOptions(
        ExerciseDimension.secondaryMuscle,
        options,
      );
      expect(
        opts.firstWhere((o) => o.label == 'Aductores').values,
        {'groin', 'inner thighs'},
      );
      expect(opts.map((o) => o.label), contains('Bíceps'));
    });

    test('target muestra la etiqueta en español', () {
      final opts = exerciseDimensionOptions(ExerciseDimension.target, options);
      expect(opts.map((o) => o.label), ['Cuádriceps', 'Dorsales']);
      expect(opts.firstWhere((o) => o.label == 'Cuádriceps').values, {'quads'});
    });

    test('cuerpo y equipo pasan sus valores tal cual', () {
      expect(
        exerciseDimensionOptions(ExerciseDimension.equipment, options)
            .map((o) => o.label),
        ['barbell'],
      );
      expect(
        exerciseDimensionOptions(ExerciseDimension.bodyPart, options)
            .map((o) => o.label),
        ['chest'],
      );
    });
  });
}