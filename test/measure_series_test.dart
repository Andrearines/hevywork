import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/domain/body_metrics.dart';
import 'package:hevywork/domain/measure_series.dart';

BodyMetric record(DateTime date, Map<String, double> measures) => BodyMetric(
      localUserId: '1',
      date: date,
      measuresJson: measures.isEmpty ? null : encodeMeasures(measures),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final now = DateTime(2026, 10, 13, 9);
  final today = DateTime(2026, 10, 13);
  final from90 = today.subtract(const Duration(days: 89));

  group('kEvolutionMeasures y etiquetas', () {
    test('las siete series en orden de los pills del mockup', () {
      expect(kEvolutionMeasures, ['chest', 'waist', 'arm', 'thigh', 'neck', 'calf', 'hip']);
    });

    test('cada serie tiene etiqueta corta en español', () {
      expect(evolutionMeasureLabel('chest'), 'Pecho');
      expect(evolutionMeasureLabel('waist'), 'Cintura');
      expect(evolutionMeasureLabel('arm'), 'Brazos');
      expect(evolutionMeasureLabel('thigh'), 'Cuádriceps');
      expect(evolutionMeasureLabel('neck'), 'Cuello');
      expect(evolutionMeasureLabel('calf'), 'Pantorrilla');
      expect(evolutionMeasureLabel('hip'), 'Glúteos');
    });
  });

  group('measureSeries', () {
    test('filtra por la ventana y omite medidas ausentes', () {
      final records = [
        record(from90.subtract(const Duration(days: 1)), {'chest': 100}),
        record(from90, {'chest': 101}),
        record(today, {'chest': 103, 'waist': 90}),
        record(today, {'arm': 33}),
      ];
      final series = measureSeries(
        records: records,
        measureId: 'chest',
        now: now,
      );
      expect(series, hasLength(2));
      expect(series.first.value, 101);
      expect(series.last.value, 103);
    });

    test('devuelve los puntos ordenados por fecha', () {
      final records = [
        record(today, {'chest': 103}),
        record(from90, {'chest': 101}),
        record(today.subtract(const Duration(days: 30)), {'chest': 102}),
      ];
      final series = measureSeries(
        records: records,
        measureId: 'chest',
        now: now,
      );
      expect(
        [for (final p in series) p.value],
        [101, 102, 103],
      );
    });

    test('una ventana más corta descarta registros antiguos', () {
      final records = [
        record(today.subtract(const Duration(days: 40)), {'chest': 100}),
        record(today.subtract(const Duration(days: 10)), {'chest': 101}),
      ];
      final series = measureSeries(
        records: records,
        measureId: 'chest',
        now: now,
        days: 30,
      );
      expect(series, hasLength(1));
      expect(series.single.value, 101);
    });
  });

  group('weeklyAxisLabels', () {
    test('las marcas son lunes dentro de la ventana', () {
      final ticks = weeklyAxisLabels(now: now);
      expect(ticks, hasLength(4));
      for (final tick in ticks) {
        expect(tick.weekday, DateTime.monday);
        expect(!tick.isBefore(from90), isTrue);
        expect(!tick.isAfter(today), isTrue);
      }
    });

    test('incluye el primer y el último lunes de la ventana', () {
      final ticks = weeklyAxisLabels(now: now);
      expect(today.difference(ticks.last).inDays, lessThan(7));
      expect(ticks.first.difference(from90).inDays, lessThan(7));
    });

    test('una ventana corta devuelve todos sus lunes', () {
      final ticks = weeklyAxisLabels(now: now, days: 21);
      expect(ticks, hasLength(3));
    });
  });

  group('cumulativeMeasureGrowth', () {
    test('suma (último − primero) de cada serie con dos puntos', () {
      final records = [
        record(today.subtract(const Duration(days: 30)), {
          'chest': 100,
          'waist': 85,
        }),
        record(today.subtract(const Duration(days: 7)), {
          'chest': 102,
          'waist': 84,
        }),
      ];
      expect(
        cumulativeMeasureGrowth(records: records, now: now),
        closeTo(1.0, 1e-9),
      );
    });

    test('null si ninguna serie tiene al menos dos puntos', () {
      final records = [record(today, {'chest': 100})];
      expect(cumulativeMeasureGrowth(records: records, now: now), isNull);
    });

    test('los puntos fuera de la ventana no cuentan', () {
      final records = [
        record(from90.subtract(const Duration(days: 100)), {'chest': 90}),
        record(today, {'chest': 100}),
      ];
      expect(cumulativeMeasureGrowth(records: records, now: now), isNull);
    });
  });

  group('measureCheckpoints y ratio cintura/pecho (stat boxes)', () {
    test('ordena los cheques y omite los que no aportan medidas', () {
      final checkpoints = measureCheckpoints([
        record(DateTime(2026, 10, 1), {'waist': 80}),
        record(DateTime(2026, 10, 5), const {}),
        record(DateTime(2026, 9, 1), {'chest': 100}),
      ]);
      expect(checkpoints, hasLength(2));
      expect(checkpoints.first.date, DateTime(2026, 9, 1));
      expect(checkpoints.last.date, DateTime(2026, 10, 1));
    });

    test('latestMeasureCheckpoint devuelve el último chequeo o null', () {
      expect(latestMeasureCheckpoint([]), isNull);
      final checkpoints = latestMeasureCheckpoint([
        record(DateTime(2026, 9, 1), {'chest': 100}),
        record(DateTime(2026, 10, 1), {'waist': 80}),
        record(DateTime(2026, 10, 5), const {}),
      ]);
      expect(checkpoints?.date, DateTime(2026, 10, 1));
      expect(checkpoints?.measures, {'waist': 80.0});
    });

    test('waistToChestRatio divide cintura entre pecho', () {
      expect(waistToChestRatio({'waist': 82, 'chest': 100}), 0.82);
      expect(waistToChestRatio({'waist': 82}), isNull);
      expect(waistToChestRatio({'waist': 82, 'chest': 0}), isNull);
    });

    test('waistToChestRatioDelta compara con el chequeo anterior', () {
      final delta = waistToChestRatioDelta(
        current: {'waist': 80, 'chest': 100},
        previous: {'waist': 84, 'chest': 100},
      );
      expect(delta, closeTo(-0.04, 1e-9));
      expect(
        waistToChestRatioDelta(
          current: {'waist': 80, 'chest': 100},
        ),
        isNull,
      );
    });
  });
}
