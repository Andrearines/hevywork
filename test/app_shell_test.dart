import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/theme/colors.dart';
import 'package:hevywork/ui/views/live_workout_view.dart';
import 'package:hevywork/ui/widgets/hevy_bottom_nav.dart';

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
  });

  tearDownAll(() => localDb.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('Tema Obsidian Kinetic', () {
    test('colores, tipografía y jerarquía sin elevación', () {
      final theme = buildAppTheme();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, kSurface);
      expect(theme.colorScheme.surface, kSurface);
      expect(theme.colorScheme.surfaceContainerHighest,
          kSurfaceContainerHighest);
      expect(theme.colorScheme.primary, kPrimary);
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.toolbarHeight, 64);

      expect(theme.textTheme.headlineSmall?.fontFamily, 'SpaceGrotesk');
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w500);
      expect(theme.textTheme.titleMedium?.fontFamily, 'SpaceGrotesk');
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Geist');
      expect(theme.textTheme.labelMedium?.fontFamily, 'Geist');
      expect(theme.textTheme.labelMedium?.fontWeight, FontWeight.w600);

      final hevyColors = theme.extension<HevyColors>();
      expect(hevyColors, isNotNull);
      expect(hevyColors!.oliveAccent, kOliveAccent);
      expect(hevyColors.surfaceBright, kSurfaceBright);
    });

    test('las dos familias están empaquetadas en pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('family: SpaceGrotesk'));
      expect(pubspec, contains('family: Geist'));
      for (final font in const [
        'SpaceGrotesk-Regular.ttf',
        'SpaceGrotesk-Medium.ttf',
        'SpaceGrotesk-SemiBold.ttf',
        'SpaceGrotesk-Bold.ttf',
        'Geist-Regular.ttf',
        'Geist-Medium.ttf',
        'Geist-SemiBold.ttf',
      ]) {
        expect(pubspec, contains('assets/fonts/$font'));
      }
    });
  });

  group('Navegación de 4 destinos', () {
    testWidgets('la barra inferior trae los cuatro destinos del designer',
        (tester) async {
      await tester.pumpWidget(const HevyWorkApp());
      await tester.pumpAndSettle();

      expect(find.byType(HevyBottomNav), findsOneWidget);
      for (final label in const ['ENTRENAR', 'RUTINAS', 'PROGRESO', 'PERFIL']) {
        expect(find.text(label), findsOneWidget);
      }

      expect(find.text('HevyWork'), findsNothing);
      expect(find.text('Entrenar'), findsOneWidget);
      expect(find.text('Historial & Calendario'), findsOneWidget);
      expect(find.text('Sin sesiones todavía'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('la cabecera muestra el logo en lugar de texto', (tester) async {
      await tester.pumpWidget(const HevyWorkApp());
      await tester.pumpAndSettle();

      expect(find.byKey(Key('app-bar-logo')), findsOneWidget);
      expect(find.text('HevyWork'), findsNothing);

      await unmount(tester);
    });

    testWidgets('al cambiar de destino cambian vista y título', (tester) async {
      await tester.pumpWidget(const HevyWorkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('PROGRESO'));
      await tester.pumpAndSettle();

      expect(find.text('Progreso'), findsWidgets);
      expect(find.text('Mis metas'), findsOneWidget);
      expect(find.text('Nueva meta'), findsOneWidget);
      expect(find.text('Sin sesiones todavía'), findsNothing);

      await tester.tap(find.text('ENTRENAR'));
      await tester.pumpAndSettle();

      expect(find.text('Sin sesiones todavía'), findsOneWidget);
      expect(find.text('Historial & Calendario'), findsOneWidget);
      expect(find.text('Progreso'), findsNothing);

      await unmount(tester);
    });

    testWidgets('el icono de búsqueda abre el catálogo desde Entrenar',
        (tester) async {
      await tester.pumpWidget(const HevyWorkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Ejercicios'), findsOneWidget);
      expect(find.text('Buscar ejercicio...'), findsOneWidget);
      expect(find.text('No hay ejercicios'), findsOneWidget);
      expect(find.text('Sin sesiones todavía'), findsNothing);

      await unmount(tester);
    });

    testWidgets('el avatar del app bar lleva al perfil', (tester) async {
      await tester.pumpWidget(const HevyWorkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Próximamente podrás editar tu perfil y tus medidas.'),
        findsNothing,
      );
      expect(find.text('Tus métricas'), findsOneWidget);
      expect(find.text('Perfil'), findsWidgets);

      await unmount(tester);
    });
  });

  group('Reanudar sesión al arrancar (RF-10/RF-11 de la 002)', () {
    Future<void> backdateSession(String workoutId, Duration age) async {
      await (localDb.update(localDb.workouts)
            ..where((t) => t.id.equals(workoutId)))
          .write(WorkoutsCompanion(
        startedAt: Value(DateTime.now().subtract(age)),
      ));
    }

    testWidgets('una sesión activa reciente se reabre sola', (tester) async {
      await workoutRepository.startWorkout();

      await tester.pumpWidget(const HevyWorkApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LiveWorkoutView), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('una sesión de más de 7 días pregunta y Abandonar la cierra '
        '(RF-11/RF-19)', (tester) async {
      final workout = await workoutRepository.startWorkout();
      await backdateSession(workout.id, const Duration(days: 8));

      await tester.pumpWidget(const HevyWorkApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sesión sin terminar'), findsOneWidget);
      expect(find.byType(LiveWorkoutView), findsNothing);

      await tester.tap(find.text('Abandonar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final stored = await (localDb.select(localDb.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.status, 'abandoned');
      expect(find.byType(LiveWorkoutView), findsNothing);

      await unmount(tester);
    });

    testWidgets('una sesión antigua se reanuda desde el aviso', (tester) async {
      final workout = await workoutRepository.startWorkout();
      await backdateSession(workout.id, const Duration(days: 9));

      await tester.pumpWidget(const HevyWorkApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reanudar'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LiveWorkoutView), findsOneWidget);

      await unmount(tester);
    });
  });
}