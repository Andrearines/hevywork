import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/fatigue_trend.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

void main() {
  final now = DateTime(2026, 10, 27, 18);

  FatigueSet set({
    required DateTime endedAt,
    double volume = 1000,
    String setType = 'normal',
    String target = 'quads',
    List<String> secondaryMuscles = const [],
  }) =>
      (
        endedAt: endedAt,
        volume: volume,
        setType: setType,
        target: target,
        secondaryMuscles: secondaryMuscles,
      );

  test('sin datos devuelve lista vacía', () {
    expect(fatigueTrend(sets: const [], now: now), isEmpty);
  });

  test('un punto por día en la ventana de 14 días, hoy el último', () {
    final points = fatigueTrend(
      sets: [set(endedAt: now.subtract(const Duration(days: 2)))],
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    expect(points.last.day, DateTime(2026, 10, 27));
    expect(points.first.day, DateTime(2026, 10, 14));
    // A los 2 días el primario ya está en Óptimo; los días sin aporte, 0.
    expect(points[11].value, kOptimalValue);
    expect(points.first.value, 0);
    expect(points.last.value, 0);
  });

  test('los valores viven en el rango 0–1 y hoy refleja la serie de hoy', () {
    final points = fatigueTrend(
      sets: [
        set(endedAt: now, volume: 5000),
        set(endedAt: now.subtract(const Duration(days: 1))),
        set(
          endedAt: now.subtract(const Duration(days: 10)),
          target: 'lats',
        ),
      ],
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    for (final point in points) {
      expect(point.value, inInclusiveRange(0, 1));
    }
    expect(points.last.value, kHighValue, reason: 'primario el día de hoy');
    expect(points[12].value, kHighValue);
  });

  test('con músculo concreto solo puntúa ese músculo', () {
    final sets = [
      set(endedAt: now, target: 'quads'),
      set(endedAt: now, target: 'lats'),
      set(endedAt: now, target: 'bench', secondaryMuscles: const ['biceps']),
    ];

    final quads = fatigueTrend(sets: sets, now: now, muscle: 'quadriceps');
    final biceps = fatigueTrend(sets: sets, now: now, muscle: 'biceps');
    final abs = fatigueTrend(sets: sets, now: now, muscle: 'abdominals');

    expect(quads.last.value, kHighValue);
    // 'bench' no es un alias válido: sus secundarios (biceps) cuentan.
    expect(biceps.last.value, kOptimalValue, reason: 'secundario en Óptimo');
    // Sin series del músculo pedido no hay datos → lista vacía.
    expect(abs, isEmpty);
  });

  test('un músculo sin series en la ventana devuelve lista vacía (RF: sin '
      'datos)', () {
    final points = fatigueTrend(
      sets: [set(endedAt: now, target: 'lats')],
      now: now,
      muscle: 'quadriceps',
    );

    expect(points, isEmpty);
  });

  test('datos del músculo fuera de recuperación devuelven la ventana a cero',
      () {
    final points = fatigueTrend(
      sets: [set(endedAt: now.subtract(const Duration(days: 10)))],
      now: now,
      muscle: 'quadriceps',
    );

    expect(points, hasLength(kFatigueTrendDays));
    expect(points.every((p) => p.value == 0), isTrue);
  });

  test('las series futuras no rompen la ventana', () {
    final points = fatigueTrend(
      sets: [set(endedAt: now.add(const Duration(days: 1)))],
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    expect(points.every((p) => p.value == 0), isTrue);
  });

  test('la ventana personalizada respeta los días pedidos', () {
    final points = fatigueTrend(
      sets: [set(endedAt: now)],
      days: 3,
      now: now,
    );

    expect(points, hasLength(3));
    expect(points.last.day, DateTime(2026, 10, 27));
  });

  test('una serie secundaria alimenta la tendencia global', () {
    final points = fatigueTrend(
      sets: [
        set(
          endedAt: now.subtract(const Duration(hours: 5)),
          target: 'grip',
          secondaryMuscles: const ['forearms'],
        ),
      ],
      now: now,
    );

    // 'grip' no es un alias canónico: solo aporta el secundario, que se
    // queda en Óptimo.
    expect(points.last.value, kOptimalValue);
  });
}
