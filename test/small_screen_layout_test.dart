import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/photo_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/profile_view.dart';
import 'package:hevywork/ui/views/progress_view.dart';
import 'package:hevywork/ui/views/routines_view.dart';
import 'package:hevywork/ui/views/train_view.dart';
import 'package:hevywork/ui/widgets/hevy_bottom_nav.dart';

/// Regresión de layout (plan_desidingIU T-1/T-4): las cuatro pestañas deben
/// montar sin excepciones de renderizado en un móvil estrecho (320 dp) y con
/// la escala de texto del sistema ampliada (1.3), sin que la pill flotante
/// tape el contenido.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
    profileRepository = ProfileRepository(localDb);
    photoRepository = PhotoRepository(localDb);
  });

  tearDownAll(() => localDb.close());

  Future<void> pumpTab(
    WidgetTester tester,
    Widget body, {
    required double textScale,
  }) async {
    tester.view.physicalSize = const Size(640, 1366);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Stack(
            children: [
              Padding(
                key: const Key('contenido-prueba'),
                padding: const EdgeInsets.only(
                  bottom: HevyBottomNav.height + 20 + 12,
                ),
                child: body,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HevyBottomNav(
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Cualquier RenderFlex overflowed u otro error de renderizado se vuelca
    // aquí como excepción del framework.
    expect(tester.takeException(), isNull);

    // La pill flotante no solapa el final del contenido scrolleable: el
    // cuerpo reserva (altura de la pill + su offset + un hueco) por debajo.
    const bottomInset = HevyBottomNav.height + HevyBottomNav.bottomOffset + 12;
    final bodyRect = tester.getRect(find.byKey(const Key('contenido-prueba')));
    final pillRect = tester.getRect(find.byType(HevyBottomNav));
    expect(bodyRect.bottom - bottomInset, lessThanOrEqualTo(pillRect.top));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  final tabs = <String, Widget Function()>{
    'Entrenar': () => const TrainView(),
    'Rutinas': () => const RoutinesView(),
    'Progreso': () => const ProgressView(),
    'Perfil': () => const ProfileView(),
  };

  for (final scale in [1.0, 1.3]) {
    testWidgets('móvil estrecho (320 dp) y escala de texto $scale — sin '
        'desbordes en ninguna pestaña', (tester) async {
      for (final entry in tabs.entries) {
        await pumpTab(tester, entry.value(), textScale: scale);
        expect(find.byType(MaterialApp), findsNothing, reason: entry.key);
      }
    });
  }
}
