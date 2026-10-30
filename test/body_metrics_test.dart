import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/body_metrics.dart';

void main() {
  group('kBodyMeasures y etiquetas', () {
    test('las siete medidas en orden de visualización', () {
      expect(kBodyMeasures, [
        'neck',
        'chest',
        'arm',
        'waist',
        'thigh',
        'calf',
        'hip',
      ]);
    });

    test('cada medida tiene etiqueta en español', () {
      expect(measureLabel('neck'), 'Cuello');
      expect(measureLabel('chest'), 'Pecho');
      expect(measureLabel('arm'), 'Brazo');
      expect(measureLabel('waist'), 'Cintura');
      expect(measureLabel('thigh'), 'Pierna');
      expect(measureLabel('calf'), 'Pantorrilla');
      expect(measureLabel('hip'), 'Glúteos');
      expect(measureLabel('unknown'), 'unknown');
    });
  });

  group('decodeMeasures / encodeMeasures (RF-1)', () {
    test('null o vacío devuelven mapa vacío', () {
      expect(decodeMeasures(null), isEmpty);
      expect(decodeMeasures(''), isEmpty);
      expect(decodeMeasures('   '), isEmpty);
    });

    test('JSON inválido devuelve mapa vacío', () {
      expect(decodeMeasures('no es json'), isEmpty);
      expect(decodeMeasures('[1,2,3]'), isEmpty);
    });

    test('convierte los valores numéricos a double', () {
      expect(decodeMeasures('{"chest": 102.5, "arm": 38}'), {
        'chest': 102.5,
        'arm': 38.0,
      });
    });

    test('ignora entradas no numéricas', () {
      expect(decodeMeasures('{"chest": "grande", "arm": 38}'), {'arm': 38.0});
    });

    test('round-trip con encodeMeasures', () {
      final json = encodeMeasures(const {'chest': 102.5, 'calf': 40});
      expect(decodeMeasures(json), const {'chest': 102.5, 'calf': 40.0});
    });
  });

  group('measureDeltas (RF-3)', () {
    test('calcula el delta frente al registro anterior', () {
      final deltas = measureDeltas(
        current: const {'chest': 102.5, 'arm': 37.5},
        previous: const {'chest': 102, 'arm': 38},
      );
      expect(deltas['chest'], 0.5);
      expect(deltas['arm'], -0.5);
    });

    test('null si falta en cualquiera de los dos lados', () {
      final deltas = measureDeltas(
        current: const {'chest': 102.5},
        previous: const {'arm': 38},
      );
      expect(deltas['chest'], isNull);
      expect(deltas['arm'], isNull);
    });

    test('sin registro anterior todos los deltas son null', () {
      final deltas = measureDeltas(current: const {'chest': 102.5});
      expect(deltas.values.every((delta) => delta == null), isTrue);
    });
  });
}