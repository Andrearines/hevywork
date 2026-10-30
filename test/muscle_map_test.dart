import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/domain/muscle_map_adaptor.dart';
import 'package:hevywork/ui/widgets/muscle_map.dart';
import 'package:muscle_mapper/muscle_mapper.dart';

/// Mapa con fatiga repartida para el golden: pecho y cuádriceps muy cargados,
/// deltoides tibios, resto frío. Valores 0–1 (RF-2).
const _sampleFront = {
  'pectoralis_major': 0.95,
  'deltoids': 0.40,
  'biceps': 0.30,
  'forearms': 0.12,
  'abdominals': 0.05,
  'obliques': 0.00,
  'quadriceps': 0.80,
  'calves': 0.22,
};

const _sampleBack = {
  'trapezius': 0.35,
  'rhomboids': 0.10,
  'latissimus_dorsi': 0.90,
  'lower_back': 0.55,
  'glutes': 0.28,
  'hamstrings': 0.45,
  'deltoids': 0.40,
  'triceps': 0.20,
  'forearms': 0.12,
  'calves': 0.22,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('adaptador canónico → muscle_mapper (RF-33)', () {
    test('los 17 canónicos de la 007 traducen a grupos del paquete', () {
      expect(kCanonicalMuscles, hasLength(17));
      for (final canonical in kCanonicalMuscles) {
        expect(
          muscleGroupsFor(canonical),
          isNotEmpty,
          reason: '$canonical debe mapear a algún grupo',
        );
      }
    });

    test('cada canónico produce músculos pintables en su vista', () {
      for (final canonical in kCanonicalMuscles) {
        final front = musclesForCanonical(canonical, AnatomyView.front);
        final back = musclesForCanonical(canonical, AnatomyView.back);
        expect(
          front.isEmpty && back.isEmpty,
          isFalse,
          reason: '$canonical debe pintar en frente o espalda',
        );
      }
    });

    test('el pecho solo va en la frente y los dorsales solo en la espalda', () {
      expect(
        musclesForCanonical('pectoralis_major', AnatomyView.front),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('pectoralis_major', AnatomyView.back),
        isEmpty,
      );
      expect(
        musclesForCanonical('latissimus_dorsi', AnatomyView.back),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('latissimus_dorsi', AnatomyView.front),
        isEmpty,
      );
    });

    test('antebrazos y gemelos aparecen en ambas vistas', () {
      expect(
        musclesForCanonical('forearms', AnatomyView.front),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('forearms', AnatomyView.back),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('calves', AnatomyView.front),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('calves', AnatomyView.back),
        isNotEmpty,
      );
    });

    test('los pies solo van en la frente y las manos en ambas vistas', () {
      expect(
        musclesForCanonical('feet', AnatomyView.front),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('feet', AnatomyView.back),
        isEmpty,
      );
      expect(
        musclesForCanonical('hands', AnatomyView.front),
        isNotEmpty,
      );
      expect(
        musclesForCanonical('hands', AnatomyView.back),
        isNotEmpty,
      );
    });
  });

  group('buildMuscleColors (RF-33)', () {
    test('asigna a cada músculo el color de su canónico', () {
      final colors = buildMuscleColors(
        {'pectoralis_major': 1.0},
        view: AnatomyView.front,
      );

      expect(colors, isNotEmpty);
      expect(colors.values.toSet(), {kFatigueHot});
    });

    test('con vacío no hay colores y la base se ve en gris neutro', () {
      expect(
        buildMuscleColors(const {}, view: AnatomyView.front),
        isEmpty,
      );
    });

    test('cada canónico recibe su color en la vista donde pinta', () {
      // Dorsales (solo espalda) y pecho (solo frente): cada uno tiñe su
      // vista con su color, sin mezclarse entre vistas.
      final front = buildMuscleColors(
        {'pectoralis_major': 1.0, 'latissimus_dorsi': 0.0},
        view: AnatomyView.front,
      );
      expect(front.values.toSet(), {kFatigueHot});

      final back = buildMuscleColors(
        {'pectoralis_major': 1.0, 'latissimus_dorsi': 0.0},
        view: AnatomyView.back,
      );
      expect(back.values.toSet(), {kFatigueCold});
    });

    test('los canónicos comparten su color en las dos vistas donde pintan', () {
      // Dorsales (espalda) + pecho (frente): ambos con la máxima fatiga
      // deben cubrir cada vista con su color sin dejar huecos.
      final colors = buildMuscleColors(
        {'latissimus_dorsi': 1.0, 'pectoralis_major': 1.0},
        view: AnatomyView.back,
      );
      expect(colors.values.toSet(), {kFatigueHot});
    });

    test('una región compartida la pinta el canónico más cargado', () {
      // Romboides y trapecio comparten la espalda media: con trapecio en
      // 0.9 y romboides en 0.1 la región no puede enfriarse.
      final colors = buildMuscleColors(
        {'trapezius': 0.9, 'rhomboids': 0.1},
        view: AnatomyView.back,
      );
      expect(colors[Muscle.trapsMiddle], fatigueColor(0.9));
      expect(colors[Muscle.upperTrapezius], fatigueColor(0.9));
    });

    test('los romboides no pisan la región de los dorsales', () {
      final colors = buildMuscleColors(
        {'latissimus_dorsi': 1.0, 'rhomboids': 0.0},
        view: AnatomyView.back,
      );
      expect(colors[Muscle.lats], fatigueColor(1.0));
    });
  });

  group('fatigueColor (RF-2)', () {
    test('0 es frío, 0.5 tibio y 1 rojo exactos', () {
      expect(fatigueColor(0), kFatigueCold);
      expect(fatigueColor(0.5), kFatigueWarm);
      expect(fatigueColor(1), kFatigueHot);
    });

    test('interpola entre frío y tibio, y entre tibio y rojo', () {
      final quarter = fatigueColor(0.25);
      expect(quarter, isNot(kFatigueCold));
      expect(quarter, isNot(kFatigueWarm));
      final threeQuarters = fatigueColor(0.75);
      expect(threeQuarters, isNot(kFatigueWarm));
      expect(threeQuarters, isNot(kFatigueHot));
    });
  });

  group('pintado del mapa vectorial (RF-33)', () {
    Future<void> pumpMap(
      WidgetTester tester,
      Map<String, double> fatigue,
      bool showBack,
      Key key,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 400,
                  child: MuscleMap(
                    fatigue: fatigue,
                    showBack: showBack,
                    height: 400,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // El `MuscleMapper` parsea el SVG de forma asíncrona: se asienta.
      await tester.pumpAndSettle();
    }

    testWidgets('pinta el widget muscle_mapper con color y toque',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 400,
                child: MuscleMap(
                  fatigue: _sampleFront,
                  onMuscleTapped: (muscle) => tapped = muscle,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MuscleMapper), findsOneWidget);
      expect(tapped, isNull);
    });

    testWidgets('golden: vista frontal con fatiga repartida',
        (tester) async {
      await pumpMap(
        tester,
        _sampleFront,
        false,
        const Key('map-front'),
      );
      await expectLater(
        find.byKey(const Key('map-front')),
        matchesGoldenFile('goldens/muscle_map_front.png'),
      );
    });

    testWidgets('golden: vista trasera con fatiga repartida', (tester) async {
      await pumpMap(
        tester,
        _sampleBack,
        true,
        const Key('map-back'),
      );
      await expectLater(
        find.byKey(const Key('map-back')),
        matchesGoldenFile('goldens/muscle_map_back.png'),
      );
    });

    testWidgets('sin datos el mapa completo se dibuja en gris neutro (RF-5)',
        (tester) async {
      await pumpMap(tester, const {}, false, const Key('map-empty'));
      await expectLater(
        find.byKey(const Key('map-empty')),
        matchesGoldenFile('goldens/muscle_map_empty.png'),
      );
    });
  });
}
