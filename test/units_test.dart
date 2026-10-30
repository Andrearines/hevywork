import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/units.dart';
import 'package:hevywork/domain/weight_progress.dart';

void main() {
  group('weightUnitOf / lengthUnitOf (RF-4)', () {
    test('métrico usa kg y cm', () {
      expect(weightUnitOf('metric'), 'kg');
      expect(lengthUnitOf('metric'), 'cm');
    });

    test('imperial usa lb y in', () {
      expect(weightUnitOf('imperial'), 'lb');
      expect(lengthUnitOf('imperial'), 'in');
    });
  });

  group('conversión de peso (kg ↔ lb)', () {
    test('displayWeightKg convierte a lb en imperial y pasa en métrico', () {
      expect(displayWeightKg(80, 'imperial'), closeTo(176.37, 0.01));
      expect(displayWeightKg(80, 'metric'), 80);
    });

    test('toKg devuelve siempre a la base kg', () {
      expect(
        toKg(displayWeightKg(80, 'imperial'), 'imperial'),
        closeTo(80, 1e-9),
      );
      expect(toKg(100, 'metric'), 100);
    });

    test('un kilogramo pesa 2,2046 lb', () {
      expect(displayWeightKg(1, 'imperial'), closeTo(2.2046, 0.001));
    });
  });

  group('conversión de longitud (cm ↔ in)', () {
    test('displayLengthCm convierte a pulgadas en imperial', () {
      expect(displayLengthCm(25.4, 'imperial'), closeTo(10, 1e-9));
      expect(displayLengthCm(100, 'metric'), 100);
    });

    test('toCm devuelve siempre a la base cm', () {
      expect(toCm(10, 'imperial'), closeTo(25.4, 1e-9));
      expect(toCm(10, 'metric'), 10);
    });
  });

  group('formateadores', () {
    test('formatDisplay: entero sin decimales, el resto con una decimal', () {
      expect(formatDisplay(80), '80');
      expect(formatDisplay(78.4), '78.4');
      expect(formatDisplay(176.369809744), '176.4');
      expect(formatDisplay(9.999999999999998), '10');
    });

    test('formatWeightKg y formatLengthCm presentan en la unidad', () {
      expect(formatWeightKg(80, 'metric'), '80');
      expect(formatWeightKg(80, 'imperial'), '176.4');
      expect(formatLengthCm(25.4, 'metric'), '25.4');
      expect(formatLengthCm(25.4, 'imperial'), '10');
      expect(formatLengthCm(100, 'imperial'), '39.4');
    });
  });

  group('pasos de edición', () {
    test('1,25 kg en métrico y 2,5 lb en imperial', () {
      expect(weightStepOf('metric'), 1.25);
      expect(weightStepOf('imperial'), 2.5);
    });

    test('1 cm en métrico y 0,5 in en imperial', () {
      expect(lengthStepOf('metric'), 1);
      expect(lengthStepOf('imperial'), 0.5);
    });
  });

  group('kgDeltaLabel con unidad (RF-4)', () {
    test('por defecto sigue en kg', () {
      expect(kgDeltaLabel(-1.2), '-1.2 kg');
      expect(kgDeltaLabel(0.4), '+0.4 kg');
    });

    test('en imperial presenta lb equivalente', () {
      expect(kgDeltaLabel(-1, unitSystem: 'imperial'), '-2.2 lb');
      expect(kgDeltaLabel(1, unitSystem: 'imperial'), '+2.2 lb');
    });
  });
}
