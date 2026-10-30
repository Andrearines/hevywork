import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hevywork/domain/services/auth_service.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/profile_view.dart';
import 'package:hevywork/ui/widgets/capped_scroll.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
    profileRepository = ProfileRepository(localDb);

    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
  });

  tearDownAll(() => localDb.close());

  setUp(() async {
    await localDb.delete(localDb.goals).go();
    await localDb.delete(localDb.bodyMetrics).go();
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
    await (localDb.update(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .write(const LocalProfilesCompanion(
      displayName: Value(null),
      unitSystem: Value('metric'),
      preferRpe: Value(false),
      sex: Value(null),
      heightCm: Value(null),
    ));
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ProfileView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedPr({
    required String exerciseId,
    required String exerciseName,
    required DateTime ended,
    required double weightKg,
    required int reps,
  }) async {
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: exerciseId,
            name: exerciseName,
            bodyPart: 'legs',
            equipment: 'barbell',
            target: 'quadriceps',
            muscleGroup: 'legs',
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await localDb.into(localDb.workouts).insert(
          WorkoutsCompanion.insert(
            id: 'w-$exerciseId',
            localUserId: profile.localUserId,
            startedAt: ended.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(ended),
          ),
        );
    await localDb.into(localDb.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: 'we-$exerciseId',
            workoutId: 'w-$exerciseId',
            exerciseId: exerciseId,
            orderIndex: 1,
          ),
        );
    await localDb.into(localDb.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: 'ws-$exerciseId',
            workoutExerciseId: 'we-$exerciseId',
            orderIndex: 1,
            weightKg: Value(weightKg),
            reps: Value(reps),
            rir: const Value(1),
            completed: const Value(true),
          ),
        );
  }

  testWidgets('perfil vacío muestra cabecera, métricas y secciones',
      (tester) async {
    await pumpView(tester);

    expect(find.text('Atleta'), findsOneWidget);
    expect(find.text('Nivel Principiante'), findsOneWidget);
    expect(find.text('Tus métricas'), findsOneWidget);
    expect(find.text('Sesiones'), findsOneWidget);
    expect(find.text('Volumen total'), findsOneWidget);
    expect(find.text('Racha'), findsOneWidget);
    expect(find.text('Aún no tienes objetivos activos.'), findsOneWidget);
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(
      find.text(
        'Sin récords este mes. Termina series para ver tus mejores marcas.',
      ),
      findsOneWidget,
    );
    expect(find.text('Configuración de Atleta'), findsOneWidget);
    expect(find.text('Unidades de medida'), findsOneWidget);
    expect(find.text('Métrico (kg / cm)'), findsOneWidget);
    expect(find.text('Ajustes de RIR y RPE'), findsOneWidget);
    expect(find.text('Cálculo automático de 1RM activo'), findsOneWidget);
    expect(find.text('Exportar datos'), findsOneWidget);
    expect(find.text('CSV / Copia de seguridad completa'), findsOneWidget);
    expect(find.text('Dispositivos'), findsOneWidget);
    expect(find.text('Báscula, caliper y frecuencia cardiaca'), findsOneWidget);
    expect(find.text('Sincronización sin configurar'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);

    await unmount(tester);
  });

  testWidgets('con sesiones terminadas muestra métricas y PR', (tester) async {
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    final ended = DateTime.now();
    await localDb.into(localDb.workouts).insert(
          WorkoutsCompanion.insert(
            id: 'w1',
            localUserId: profile.localUserId,
            startedAt: ended.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(ended),
          ),
        );
    await localDb.into(localDb.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: 'w1-item',
            workoutId: 'w1',
            exerciseId: 'bench-press',
            orderIndex: 1,
          ),
        );
    await localDb.into(localDb.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: 'w1-set',
            workoutExerciseId: 'w1-item',
            orderIndex: 1,
            weightKg: const Value(80),
            reps: const Value(5),
            rir: const Value(1),
            completed: const Value(true),
          ),
        );

    await pumpView(tester);

    expect(find.text('Nivel Principiante'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('80 kg × 5'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('editar el nombre lo persiste', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Atleta'));
    await tester.pumpAndSettle();

    expect(find.text('Tu nombre'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('cambiar unidades a imperial actualiza el resumen',
      (tester) async {
    await pumpView(tester);

    expect(find.text('Métrico (kg / cm)'), findsOneWidget);
    await tester.tap(find.text('Unidades de medida'));
    await tester.pumpAndSettle();

    expect(find.text('Unidades de medida'), findsNWidgets(2));
    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Imperial (lb / in)'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('preferir RPE cambia el subtítulo de RIR y RPE',
      (tester) async {
    await pumpView(tester);

    expect(find.text('Cálculo automático de 1RM activo'), findsOneWidget);
    await tester.tap(find.text('Ajustes de RIR y RPE'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes de RIR y RPE'), findsNWidgets(2));
    await tester.tap(find.text('RPE (esfuerzo percibido)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Esfuerzo percibido (RPE) activo'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('elegir sexo lo persiste para la estimación (spec 009)',
      (tester) async {
    await pumpView(tester);

    await tester.dragUntilVisible(
      find.text('Sexo'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin especificar'), findsWidgets);

    await tester.tap(find.text('Sexo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mujer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Mujer'), findsOneWidget);
    final profile = await profileRepository.current();
    expect(profile.sex, 'female');

    await unmount(tester);
  });

  testWidgets('editar la altura la guarda en cm (spec 009, RF-4)',
      (tester) async {
    await pumpView(tester);

    await tester.dragUntilVisible(
      find.text('Altura'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Altura'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Altura (cm)'),
      '180',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('180 cm'), findsOneWidget);
    final profile = await profileRepository.current();
    expect(profile.heightCm, 180);

    await unmount(tester);
  });

  testWidgets('exportar datos avisa si el sistema no está disponible',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('hevywork_export');
    final pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    var shareCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => tempDir.path,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        shareCalls++;
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    await pumpView(tester);

    await tester.tap(find.text('Exportar datos'));
    await tester.pump();
    var iterations = 0;
    while (shareCalls == 0 && iterations < 50) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      iterations++;
    }
    await tester.pumpAndSettle();

    expect(find.text('La exportación no está disponible aquí'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('dispositivos enlaza a la pantalla de reserva (spec 011)',
      (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Dispositivos'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Próximamente podrás conectar tu báscula, tu caliper y leer tu frecuencia cardiaca.',
      ),
      findsOneWidget,
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(find.text('Configuración de Atleta'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('fila de cuenta sin sesión abre el diálogo de correo',
      (tester) async {
    final goTrue = FakeGoTrue();
    authService = AuthService(FakeSupabase(goTrue), localDb);
    addTearDown(() => authService = null);

    await pumpView(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
      'sin configuración de Supabase la fila explica el motivo y no abre nada',
      (tester) async {
    authService = null;

    await pumpView(tester);

    expect(find.text('Sincronización sin configurar'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(
      find.text(
        'Falta la configuración de Supabase: arranca la app '
        'con tool/run.sh para poder iniciar sesión.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Sincronización sin configurar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);

    await unmount(tester);
  });

  testWidgets('enviar vacío muestra validación en el diálogo', (tester) async {
    authService = AuthService(FakeSupabase(FakeGoTrue()), localDb);
    addTearDown(() => authService = null);

    await pumpView(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(
      find.text('Escribe tu correo y tu contraseña.'),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('credenciales incorrectas muestran el error traducido',
      (tester) async {
    final goTrue = FakeGoTrue()
      ..signInError = const AuthException('Invalid login credentials');
    authService = AuthService(FakeSupabase(goTrue), localDb);
    addTearDown(() => authService = null);

    await pumpView(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).at(0), 'atleta@hevywork.app');
    await tester.enterText(find.byType(TextField).at(1), 'mala');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('con credenciales válidas cierra el diálogo y muestra cerrar',
      (tester) async {
    final goTrue = FakeGoTrue();
    authService = AuthService(FakeSupabase(goTrue), localDb);
    addTearDown(() => authService = null);

    await pumpView(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).at(0), 'atleta@hevywork.app');
    await tester.enterText(find.byType(TextField).at(1), 'clave-secreta');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    await unmount(tester);
  });

  testWidgets(
      'los récords filtran el mes actual y el histórico va en su pestaña',
      (tester) async {
    await seedPr(
      exerciseId: 'squat',
      exerciseName: 'Sentadilla',
      ended: DateTime.now(),
      weightKg: 100,
      reps: 5,
    );
    await seedPr(
      exerciseId: 'bench-press',
      exerciseName: 'Press de banca',
      ended: DateTime.now().subtract(const Duration(days: 45)),
      weightKg: 80,
      reps: 5,
    );

    await pumpView(tester);

    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('100 kg × 5'), findsOneWidget);
    expect(find.text('Press de banca'), findsNothing);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('80 kg × 5'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);

    await tester.tap(find.text('Este mes'));
    await tester.pumpAndSettle();

    expect(find.text('Press de banca'), findsNothing);
    expect(find.text('Sentadilla'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('los objetivos se limitan a 3 filas con scroll interno (RF-13)',
      (tester) async {
    await goalRepository.createGoal(type: 'bodyweight', targetValue: 85);
    await goalRepository.createGoal(type: 'consistency', targetValue: 4);
    await goalRepository.createGoal(
      type: 'strength',
      targetValue: 100,
      metricRef: 'bench-press',
    );

    await pumpView(tester);

    expect(
      find.descendant(
        of: find.byType(CappedScroll),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(find.text('Peso corporal'), findsOneWidget);

    await goalRepository.createGoal(
      type: 'volume',
      targetValue: 1000,
      period: 'weekly',
      metricRef: 'bench-press',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    final capped = find.byType(CappedScroll);
    expect(capped, findsOneWidget);
    expect(
      find.descendant(of: capped, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    await tester.ensureVisible(capped);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final section = tester.getRect(capped);
    final titles = const ['Peso corporal', 'Constancia', 'Fuerza', 'Volumen'];

    bool visible(String title) {
      final rect = tester.getRect(
        find.descendant(of: capped, matching: find.text(title)),
      );
      return rect.top >= section.top && rect.bottom <= section.bottom;
    }

    final hidden = titles.where((title) => !visible(title)).toList();
    expect(hidden, hasLength(1));

    await tester.drag(capped, const Offset(0, -220));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getRect(capped).top, closeTo(section.top, 0.5));
    expect(visible(hidden.single), isTrue);

    await unmount(tester);
  });

  testWidgets(
      'sin sesión, tocar el avatar explica que hace falta iniciar (RF-3)',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpView(tester);

    await tester.tap(find.bySemanticsLabel('Cambiar foto de perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión para subir tu foto'), findsOneWidget);
    expect(find.text('Cámara'), findsNothing);
    expect(find.text('Galería'), findsNothing);

    semantics.dispose();
    await unmount(tester);
  });
}
