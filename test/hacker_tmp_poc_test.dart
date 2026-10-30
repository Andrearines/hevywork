// PoC temporal del agente hacker — se borra tras la verificación.
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/fatigue_trend.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

void main() {
  test('PoC: solapamiento de cubos diarios en cambios de hora (DST)', () {
    final now = DateTime(2026, 3, 30, 12);

    FatigueSet set(DateTime at) => (
          endedAt: at,
          volume: 100.0,
          setType: 'normal',
          target: 'quads',
          secondaryMuscles: const <String>[],
        );

    // Única serie: mediodía de hoy.
    final points = fatigueTrend(sets: [set(DateTime(2026, 3, 30, 12))], now: now);

    final nonzero = [
      for (final p in points)
        if (p.value > 0) p.day.toString(),
    ];
    // ignore: avoid_print
    print('TZ=${DateTime.now().timeZoneName} días con aporte: $nonzero');
    for (final p in points) {
      // ignore: avoid_print
      print('  ${p.day.toIso8601String()} -> ${p.value}');
    }

    // Un solo día debe tener aporte. Con TZ con cambio de hora (Europa),
    // el cubo de «ayer» engloba también parte (o todo) de «hoy».
    expect(
      nonzero,
      hasLength(1),
      reason: 'una única serie de hoy debe caer solo en el día de hoy',
    );
  });
}
