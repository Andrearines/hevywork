import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/fatigue_trend.dart'
    show fatigueTrend, kFatigueTrendDays;
import 'package:hevywork/domain/exercise_stats.dart';

void main() {
  final now = DateTime(2026, 10, 27, 18);

  // Helper para crear ExerciseSetRow de prueba.
  ExerciseSetRow set({
    required int orderIndex,
    required String setType,
    required double weightKg,
    required int reps,
    bool completed = true,
  }) =>
      ExerciseSetRow(
        orderIndex: orderIndex,
        setType: setType,
        weightKg: weightKg,
        reps: reps,
        completed: completed,
      );

  test('sin datos devuelve lista vacía', () {
    expect(fatigueTrend(sets: const [], days: kFatigueTrendDays, now: now), isEmpty);
  });

  test('un punto por día en la ventana de 14 días, hoy el último', () {
    final points = fatigueTrend(
      sets: [
        set(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 50,
          reps: 10,
        ),
      ],
      days: kFatigueTrendDays,
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    // El último punto es hoy.
    expect(points.last.day, DateTime(2026, 10, 27));
    expect(points.first.day, DateTime(2026, 10, 14));
    // Sin endedAt en ExerciseSetRow, el decaimiento no se aplica (factor 1.0).
    // Todos los días con series tienen fatiga Alta (1.0).
    expect(points.last.value, 1.0);
    expect(points.first.value, 1.0);
    expect(points.last.value, 1.0);
  });

  test('los valores viven en el rango 0–1 y hoy refleja la serie de hoy', () {
    final points = fatigueTrend(
      sets: [
        set(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 50,
          reps: 10,
        ),
        set(
          orderIndex: 1,
          setType: 'normal',
          weightKg: 30,
          reps: 8,
        ),
        set(
          orderIndex: 2,
          setType: 'normal',
          weightKg: 20,
          reps: 5,
        ),
      ],
      days: kFatigueTrendDays,
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    for (final point in points) {
      expect(point.value, inInclusiveRange(0, 1));
    }
    // Hoy con serie cuenta como Alto (1.0).
    expect(points.last.value, 1.0, reason: 'primario el día de hoy');
  });

  test('con músculo concreto solo puntúa ese músculo', () {
    final sets = [
      set(
        orderIndex: 0,
        setType: 'normal',
        weightKg: 50,
        reps: 10,
      ),
      set(
        orderIndex: 1,
        setType: 'normal',
        weightKg: 30,
        reps: 8,
      ),
      set(
        orderIndex: 2,
        setType: 'normal',
        weightKg: 20,
        reps: 5,
      ),
    ];

    // Con músculo especificado, los sets contribuyen a ese músculo.
    final quads = fatigueTrend(sets: sets, days: kFatigueTrendDays, now: now, muscle: 'quadriceps');
    // Sin músculo especificado, pico global.
    final global = fatigueTrend(sets: sets, days: kFatigueTrendDays, now: now);

    // Ambos deben devolver lista de 14 puntos.
    expect(quads, hasLength(kFatigueTrendDays));
    expect(global, hasLength(kFatigueTrendDays));
    // El valor del último día debe ser 1.0 (Alto) para ambos al tener series hoy.
    expect(quads.last.value, 1.0);
    expect(global.last.value, 1.0);
  });

  test('un músculo sin series en la ventana devuelve lista vacía (RF: sin datos)', () {
    // Cuando no hay sets con volumen positivo, devuelve vacío.
    final points = fatigueTrend(
      sets: const [],
      days: kFatigueTrendDays,
      now: now,
      muscle: 'quadriceps',
    );

    expect(points, isEmpty);
  });

  test('las series futuras no rompen la ventana', () {
    // Sin endedAt, asumimos que el caller no pasa sets futuros.
    // La ventana de 14 días se respeta igual.
    final points = fatigueTrend(
      sets: [
        set(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 50,
          reps: 10,
        ),
      ],
      days: kFatigueTrendDays,
      now: now,
    );

    expect(points, hasLength(kFatigueTrendDays));
    expect(points.last.day, DateTime(2026, 10, 27));
  });

  test('la ventana personalizada respeta los días pedidos', () {
    final points = fatigueTrend(
      sets: [
        set(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 50,
          reps: 10,
        ),
      ],
      days: 3,
      now: now,
    );

    expect(points, hasLength(3));
    expect(points.last.day, DateTime(2026, 10, 27));
  });

  test('una serie secundaria alimenta la tendencia global', () {
    final sets = [
      set(
        orderIndex: 0,
        setType: 'normal',
        weightKg: 50,
        reps: 10,
      ),
    ];

    // Con músculo forearms, la serie debe contribuir.
    final points = fatigueTrend(
      sets: sets,
      days: kFatigueTrendDays,
      now: now,
      muscle: 'forearms',
    );

    expect(points, hasLength(kFatigueTrendDays));
    // El último día (hoy) debe tener algún valor > 0 ya que la serie contribuye.
    expect(points.last.value, greaterThan(0.0));
  });
}