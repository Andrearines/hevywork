import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

void main() {
  group('kTargetMuscleAliases (primario real, amenda 2026-10-22)', () {
    test('mapea el vocabulario `target` a la zona canónica', () {
      expect(kTargetMuscleAliases['pectorals'], 'pectoralis_major');
      expect(kTargetMuscleAliases['lats'], 'latissimus_dorsi');
      expect(kTargetMuscleAliases['delts'], 'deltoids');
      expect(kTargetMuscleAliases['quads'], 'quadriceps');
      expect(kTargetMuscleAliases['abs'], 'abdominals');
      expect(kTargetMuscleAliases['upper back'], 'rhomboids');
      expect(kTargetMuscleAliases['spine'], 'lower_back');
      expect(kTargetMuscleAliases['traps'], 'trapezius');
      expect(kTargetMuscleAliases['glutes'], 'glutes');
    });

    test('los objetivos sin región propia se adscriben a la más próxima', () {
      expect(kTargetMuscleAliases['abductors'], 'glutes');
      expect(kTargetMuscleAliases['adductors'], 'quadriceps');
      expect(kTargetMuscleAliases['levator scapulae'], 'trapezius');
      expect(kTargetMuscleAliases['serratus anterior'], 'obliques');
    });

    test('cardiovascular system no es un músculo y no tiene zona', () {
      expect(kTargetMuscleAliases['cardiovascular system'], isNull);
    });

    test('todos los aliases caen en un músculo dibujado', () {
      for (final canonical in kTargetMuscleAliases.values) {
        expect(kMapMuscles, contains(canonical));
      }
    });
  });

  group('kMuscleAliases (vocabulario de secundarios)', () {
    test('resuelve los nombres no normalizados del caso límite', () {
      expect(kMuscleAliases['lats'], 'latissimus_dorsi');
      expect(kMuscleAliases['latissimus dorsi'], 'latissimus_dorsi');
      expect(kMuscleAliases['traps'], 'trapezius');
      expect(kMuscleAliases['shoulders'], 'deltoids');
      expect(kMuscleAliases['chest'], 'pectoralis_major');
      expect(kMuscleAliases['upper back'], 'rhomboids');
      expect(kMuscleAliases['core'], 'abdominals');
      expect(kMuscleAliases['soleus'], 'calves');
      expect(kMuscleAliases['wrists'], 'forearms');
    });

    test('los grupos sin región propia se adscriben a la más próxima', () {
      expect(kMuscleAliases['hip flexors'], 'quadriceps');
      expect(kMuscleAliases['rotator cuff'], 'deltoids');
      expect(kMuscleAliases['ankles'], 'feet');
      expect(kMuscleAliases['ankle stabilizers'], 'feet');
      expect(kMuscleAliases['hands'], 'hands');
    });

    test('todos los aliases caen en un músculo dibujado', () {
      for (final canonical in kMuscleAliases.values) {
        expect(kMapMuscles, contains(canonical));
      }
    });
  });

  test('el mapa dibuja los 17 músculos canónicos', () {
    expect(kMapMuscles, hasLength(17));
    expect(
      kMapMuscles,
      containsAll([
        'pectoralis_major',
        'latissimus_dorsi',
        'trapezius',
        'quadriceps',
        'glutes',
      ]),
    );
  });

  group('setFatigueFactor (RF-1)', () {
    test('normal y failure valen 1.0, drop 0.5, warmup 0', () {
      expect(setFatigueFactor('normal'), 1.0);
      expect(setFatigueFactor('failure'), 1.0);
      expect(setFatigueFactor('drop'), 0.5);
      expect(setFatigueFactor('warmup'), 0);
    });

    test('un tipo desconocido se trata como normal', () {
      expect(setFatigueFactor('raro'), 1.0);
    });
  });

  group('fatigueDecayFactor (RF-1)', () {
    final now = DateTime(2026, 10, 9, 12);

    test('hoy no decae; el futuro tampoco', () {
      expect(fatigueDecayFactor(now, now), 1.0);
      expect(
        fatigueDecayFactor(now, now.add(const Duration(days: 2))),
        1.0,
      );
    });

    test('dentro de la ventana decae en exponencial e^(-días/7)', () {
      expect(
        fatigueDecayFactor(now, now.subtract(const Duration(days: 2))),
        closeTo(0.7515, 0.001),
      );
    });

    test('a los 3 días el factor vale 0 (recuperación total)', () {
      expect(fatigueDecayFactor(now, now.subtract(const Duration(days: 3))), 0);
    });

    test('más allá de los 3 días el factor sigue en 0', () {
      expect(fatigueDecayFactor(now, now.subtract(const Duration(days: 7))), 0);
      expect(
        fatigueDecayFactor(now, now.subtract(const Duration(days: 14))),
        0,
      );
    });
  });

  group('rawMuscleFatigue (RF-1)', () {
    final now = DateTime(2026, 10, 9, 12);

    test('suma volumen × factor × decaimiento por músculo canónico', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now, volume: 1000, setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now, volume: 500, setType: 'drop', target: 'lats',
              secondaryMuscles: const []),
        ],
      );
      expect(raw['pectoralis_major'], 2000);
      expect(raw['latissimus_dorsi'], 250);
      expect(raw.length, 2);
    });

    test('warmup no aporta y el objetivo fuera del mapa se ignora', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'warmup', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now, volume: 1000, setType: 'normal',
              target: 'cardiovascular system', secondaryMuscles: const []),
          (endedAt: now, volume: 0, setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
        ],
      );
      expect(raw, isEmpty);
    });

    test('decae el aporte de un set en la ventana y se anula a los 3 días', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 2)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now.subtract(const Duration(days: 7)), volume: 1000,
              setType: 'normal', target: 'lats', secondaryMuscles: const []),
        ],
      );
      expect(raw['pectoralis_major'], closeTo(751.5, 0.5));
      expect(raw['latissimus_dorsi'], 0);
    });
  });

  group('secundarios del ejercicio', () {
    final now = DateTime(2026, 10, 9, 12);

    test('el secundario aporta la mitad del primario', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'normal', target: 'quads',
              secondaryMuscles: ['hamstrings', 'glutes']),
        ],
      );
      expect(raw['quadriceps'], 1000);
      expect(raw['hamstrings'], 500);
      expect(raw['glutes'], 500);
    });

    test('el secundario decae igual que el primario', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 2)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: ['biceps']),
        ],
      );
      expect(raw['biceps'], closeTo(375.8, 0.5));
    });

    test('un secundario repetido como primario no se suma dos veces', () {
      final raw = rawMuscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'normal', target: 'quads',
              secondaryMuscles: ['quadriceps']),
        ],
      );
      expect(raw['quadriceps'], 1000);
    });
  });

  group('muscleRoles (amenda 2026-10-22)', () {
    final now = DateTime(2026, 10, 9, 12);

    test('separa la antigüedad del primario y del secundario', () {
      final roles = muscleRoles(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 1)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: ['biceps']),
          (endedAt: now.subtract(const Duration(days: 4)), volume: 1000,
              setType: 'normal', target: 'quads',
              secondaryMuscles: ['glutes']),
        ],
      );
      expect(roles.primary['pectoralis_major'], closeTo(1.0, 0.001));
      expect(roles.primary['quadriceps'], closeTo(4.0, 0.001));
      expect(roles.secondary['biceps'], closeTo(1.0, 0.001));
      expect(roles.secondary['glutes'], closeTo(4.0, 0.001));
    });

    test('un warmup no reinicia el reloj del rol', () {
      final roles = muscleRoles(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 1)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now, volume: 1000, setType: 'warmup', target: 'pectorals',
              secondaryMuscles: const []),
        ],
      );
      expect(roles.primary['pectoralis_major'], closeTo(1.0, 0.001));
    });

    test('el aporte más reciente manda sobre el más antiguo', () {
      final roles = muscleRoles(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 5)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
          (endedAt: now.subtract(const Duration(days: 1)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
        ],
      );
      expect(roles.primary['pectoralis_major'], closeTo(1.0, 0.001));
    });

    test('los sets futuros no producen antigüedad negativa', () {
      final roles = muscleRoles(
        now: now,
        sets: [
          (endedAt: now.add(const Duration(days: 2)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
        ],
      );
      expect(roles.primary['pectoralis_major'], 0);
    });
  });

  group('primaryFatigueValue / secondaryFatigueValue (RF-25)', () {
    test('el primario va de Alto a Recuperado por ventana', () {
      expect(primaryFatigueValue(null), kRecoveredValue);
      expect(primaryFatigueValue(0), kHighValue);
      expect(primaryFatigueValue(1.9), kHighValue);
      expect(primaryFatigueValue(2), kOptimalValue);
      expect(primaryFatigueValue(2.9), kOptimalValue);
      expect(primaryFatigueValue(3), kRecoveredValue);
      expect(primaryFatigueValue(10), kRecoveredValue);
    });

    test('el volumen no influye en el primario', () {
      expect(primaryFatigueValue(0), kHighValue);
    });

    test('el secundario permanece en Óptimo durante su ventana', () {
      expect(secondaryFatigueValue(null), kRecoveredValue);
      expect(secondaryFatigueValue(0), kOptimalValue);
      expect(secondaryFatigueValue(1.0), kOptimalValue);
      expect(secondaryFatigueValue(1.99), kOptimalValue);
    });

    test('el secundario se recupera a los 2 días', () {
      expect(secondaryFatigueValue(2.0), kRecoveredValue);
      expect(secondaryFatigueValue(5.0), kRecoveredValue);
    });

    test('los anclajes de la escala son exactos', () {
      expect(kHighValue, 1.0);
      expect(kOptimalValue, 0.5);
      expect(kRecoveredValue, 0.0);
    });
  });

  group('muscleFatigue (RF-1 → RF-25)', () {
    final now = DateTime(2026, 10, 9);

    test('el primario toma el estado de su ventana, sin mirar el volumen', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'normal', target: 'quads',
              secondaryMuscles: const []),
          (endedAt: now.subtract(const Duration(days: 2)), volume: 200,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: const []),
        ],
      );
      expect(fatigue['quadriceps'], kHighValue);
      expect(fatigue['pectoralis_major'], kOptimalValue);
    });

    test('los glúteos como target se marcan como primarios', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 0, setType: 'normal', target: 'glutes',
              secondaryMuscles: const []),
        ],
      );
      expect(fatigue['glutes'], kHighValue);
    });

    test('un músculo recuperado queda en el mapa con valor 0 (frío)', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now.subtract(const Duration(days: 10)), volume: 1000,
              setType: 'normal', target: 'glutes',
              secondaryMuscles: const []),
        ],
      );
      expect(fatigue['glutes'], kRecoveredValue);
    });

    test('el estado de un músculo es el mayor de sus dos roles', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 1000, setType: 'normal', target: 'quads',
              secondaryMuscles: ['glutes']),
          (endedAt: now.subtract(const Duration(days: 4)), volume: 1000,
              setType: 'normal', target: 'pectorals',
              secondaryMuscles: ['glutes']),
        ],
      );
      // Glúteos: secundario hoy (Óptimo) y secundario hace 4 días
      // (Recuperado); manda el más reciente → Óptimo.
      expect(fatigue['glutes'], kOptimalValue);
    });

    test('el volumen alto no eleva a un secundario a Alto', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 5000, setType: 'normal', target: 'pectorals',
              secondaryMuscles: ['biceps']),
        ],
      );
      expect(fatigue['biceps'], kOptimalValue);
    });

    test('los sets de peso corporal cuentan para el estado del primario', () {
      final fatigue = muscleFatigue(
        now: now,
        sets: [
          (endedAt: now, volume: 0, setType: 'normal', target: 'glutes',
              secondaryMuscles: const []),
          (endedAt: now, volume: 1000, setType: 'normal', target: 'quads',
              secondaryMuscles: const []),
        ],
      );
      expect(fatigue['glutes'], kHighValue);
    });
  });

  group('zoneStatusOf/zoneStatusLabel (RF-24)', () {
    test('el rojo (más exigido) es «Alto» y el frío «Recuperado»', () {
      expect(zoneStatusOf(1.0), MuscleZoneStatus.high);
      expect(zoneStatusLabel(zoneStatusOf(1.0)), 'Alto');
      expect(zoneStatusOf(0.04), MuscleZoneStatus.recovering);
      expect(zoneStatusLabel(zoneStatusOf(0.04)), 'Recuperado');
      expect(zoneStatusLabel(zoneStatusOf(0.5)), 'Óptimo');
    });

    test('los umbrales 0.25/0.75 son exactos', () {
      expect(zoneStatusOf(0.75), MuscleZoneStatus.optimal);
      expect(zoneStatusOf(0.75001), MuscleZoneStatus.high);
      expect(zoneStatusOf(0.25), MuscleZoneStatus.recovering);
      expect(zoneStatusOf(0.25001), MuscleZoneStatus.optimal);
    });
  });
}
