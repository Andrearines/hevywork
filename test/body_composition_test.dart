import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/domain/body_composition.dart';
import 'package:hevywork/domain/body_metrics.dart';

BodyMetric _record({
  required DateTime date,
  double? weightKg,
  double? bodyFatPct,
  double? leanMassKg,
  Map<String, double>? measures,
}) {
  final timestamp = DateTime(2026, 1, 1);
  return BodyMetric(
    localUserId: 'user',
    date: date,
    weightKg: weightKg,
    bodyFatPct: bodyFatPct,
    leanMassKg: leanMassKg,
    measuresJson: measures == null ? null : encodeMeasures(measures),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  group('navyBodyFatPercent', () {
    test('hombre: cuello, cintura y altura', () {
      final value = navyBodyFatPercent(
        sex: kSexMale,
        heightCm: 180,
        neckCm: 40,
        waistCm: 90,
      );
      expect(value, isNotNull);
      expect(value!, closeTo(18.4, 0.2));
    });

    test('mujer: añade cadera al perímetro', () {
      final value = navyBodyFatPercent(
        sex: kSexFemale,
        heightCm: 165,
        neckCm: 33,
        waistCm: 75,
        hipCm: 100,
      );
      expect(value, isNotNull);
      expect(value!, closeTo(29.4, 0.2));
    });

    test('sin sexo no estima', () {
      expect(
        navyBodyFatPercent(
          sex: null,
          heightCm: 180,
          neckCm: 40,
          waistCm: 90,
        ),
        isNull,
      );
    });

    test('mujer sin cadera no estima', () {
      expect(
        navyBodyFatPercent(
          sex: kSexFemale,
          heightCm: 165,
          neckCm: 33,
          waistCm: 75,
        ),
        isNull,
      );
    });

    test('perímetros imposibles no estiman', () {
      expect(
        navyBodyFatPercent(
          sex: kSexMale,
          heightCm: 180,
          neckCm: 90,
          waistCm: 90,
        ),
        isNull,
      );
      expect(
        navyBodyFatPercent(
          sex: kSexFemale,
          heightCm: 165,
          neckCm: 40,
          waistCm: 10,
          hipCm: 20,
        ),
        isNull,
      );
    });

    test('resultado fuera del rango fisiológico no estima', () {
      expect(
        navyBodyFatPercent(
          sex: kSexMale,
          heightCm: 150,
          neckCm: 30,
          waistCm: 200,
        ),
        isNull,
      );
    });
  });

  test('leanMassKgFor aplica peso × (1 − grasa/100)', () {
    expect(leanMassKgFor(weightKg: 80, bodyFatPct: 20), closeTo(64, 1e-9));
    expect(leanMassKgFor(weightKg: null, bodyFatPct: 20), isNull);
    expect(leanMassKgFor(weightKg: 80, bodyFatPct: null), isNull);
  });

  group('compositionOf', () {
    test('la grasa manual manda sobre la estimada', () {
      final record = _record(
        date: DateTime(2026, 1, 1),
        weightKg: 80,
        bodyFatPct: 18.5,
        measures: const {'neck': 40, 'waist': 90},
      );
      final composition = compositionOf(
        record,
        sex: kSexMale,
        heightCm: 180,
      );
      expect(composition.bodyFatPct, 18.5);
      expect(composition.estimatedBodyFat, isFalse);
      expect(composition.leanMassKg, closeTo(65.2, 1e-9));
    });

    test('sin valor manual estima con US Navy y deriva la masa magra', () {
      final record = _record(
        date: DateTime(2026, 1, 1),
        weightKg: 80,
        measures: const {'neck': 40, 'waist': 90},
      );
      final composition = compositionOf(
        record,
        sex: kSexMale,
        heightCm: 180,
      );
      expect(composition.estimatedBodyFat, isTrue);
      expect(composition.bodyFatPct, closeTo(18.4, 0.2));
      expect(composition.leanMassKg, closeTo(80 * (1 - 18.4 / 100), 0.2));
    });

    test('la masa magra manual manda sobre la derivada', () {
      final record = _record(
        date: DateTime(2026, 1, 1),
        weightKg: 80,
        bodyFatPct: 20,
        leanMassKg: 61,
      );
      final composition = compositionOf(record);
      expect(composition.leanMassKg, 61);
      expect(composition.estimatedBodyFat, isFalse);
    });
  });

  group('historial de composición', () {
    final records = [
      _record(
        date: DateTime(2026, 1, 1),
        weightKg: 84,
        bodyFatPct: 20,
      ),
      _record(
        date: DateTime(2026, 2, 1),
        weightKg: 80,
        bodyFatPct: 18,
      ),
      // Solo peso: no aporta composición y no entra en el historial.
      _record(date: DateTime(2026, 3, 1), weightKg: 79),
    ];

    test('sin datos devuelve null', () {
      expect(
        latestComposition(const [], sex: kSexMale, heightCm: 180),
        isNull,
      );
      expect(
        previousComposition(const [], sex: kSexMale, heightCm: 180),
        isNull,
      );
    });

    test('última y anterior ignoran los registros sin composición', () {
      final latest = latestComposition(records);
      final previous = previousComposition(records);
      expect(latest?.bodyFatPct, 18);
      expect(previous?.bodyFatPct, 20);
      expect(latest?.leanMassKg, closeTo(65.6, 1e-9));
    });
  });

  test('bodyFatSourceLabel distingue manual y estimado', () {
    expect(bodyFatSourceLabel(estimated: true), 'Estimado · US Navy');
    expect(bodyFatSourceLabel(estimated: false), 'Registro manual');
  });
}
