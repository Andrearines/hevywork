import 'dart:convert';
import 'dart:io';

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
import 'package:hevywork/data/repositories/photo_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/progress_view.dart';

/// PNG válido de 1×1 píxel para que `Image.file` decodifique en los tests.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
    tempDir = await Directory.systemTemp.createTemp('hevywork_photos_ui');
    profileRepository = ProfileRepository(localDb);
    photoRepository = PhotoRepository(
      localDb,
      documentsDir: () async => tempDir,
    );
  });

  tearDownAll(() async {
    await localDb.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await localDb.delete(localDb.progressPhotos).go();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      null,
    );
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ProgressView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Desmonta la vista y drena los timers de 0 ms que drift programa al
  /// cancelar sus `QueryStream`.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Avanza frames con duraciones fijas: `pumpAndSettle` puede colgarse con
  /// las imágenes reales del grid, que decodifican fuera del fake clock.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> scrollToPhotos(WidgetTester tester) async {
    final photos = find.text('Fotos de Progreso');
    await tester.dragUntilVisible(
      photos,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.ensureVisible(photos);
    await settle(tester);
  }

  void mockPicker({required String pickedPath}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async {
        if (call.method == 'pickImage') return pickedPath;
        return null;
      },
    );
  }

  testWidgets('vacío: placeholders por vista, pill sin comparación y CTA',
      (tester) async {
    await pumpView(tester);
    await scrollToPhotos(tester);

    expect(find.text('Sin comparación'), findsOneWidget);
    expect(find.text('FRENTE'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('ESPALDA'), findsOneWidget);
    expect(find.text('Sin foto'), findsNWidgets(3));
    expect(find.textContaining('comparar tu progreso'), findsOneWidget);
    expect(find.text('Eliminar todo'), findsNothing);

    await unmount(tester);
  });

  testWidgets(
      'con fotos: última por vista, pie con fecha y píldora de comparación',
      (tester) async {
    await tester.runAsync(() async {
      await photoRepository.addPhoto(
        date: DateTime(2026, 1, 1),
        view: 'front',
        bytes: _tinyPng,
      );
      await photoRepository.addPhoto(
        date: DateTime(2026, 1, 1),
        view: 'side',
        bytes: _tinyPng,
      );
      await photoRepository.addPhoto(
        date: DateTime(2026, 2, 1),
        view: 'front',
        bytes: _tinyPng,
      );
    });

    await pumpView(tester);
    await scrollToPhotos(tester);

    expect(find.text('1 ene vs 1 feb'), findsOneWidget);
    expect(find.text('1 feb'), findsWidgets);
    expect(find.text('1 ene'), findsOneWidget);
    expect(find.text('Sin foto'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('añadir foto desde la cámara guarda la fila (RF-7)',
      (tester) async {
    final pickedFile = File('${tempDir.path}/picked.jpg')
      ..writeAsBytesSync(_tinyPng);
    mockPicker(pickedPath: pickedFile.path);
    final handle = tester.ensureSemantics();

    await pumpView(tester);
    await scrollToPhotos(tester);

    await tester.tap(find.bySemanticsLabel('Añadir foto de progreso'));
    await settle(tester);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);

    await tester.tap(find.text('Cámara'));
    await settle(tester);
    // El grid de fondo también rotula «Frente»: se limita al sheet (ListTile).
    expect(find.widgetWithText(ListTile, 'Frente'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Perfil'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Espalda'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Frente'));
    // `addPhoto` lee y escribe en disco (IO real): se cede al event loop
    // real y se alterna con frames hasta que la fila aparece.
    var rows = const <ProgressPhoto>[];
    for (var i = 0; i < 40; i++) {
      // Cede tiempo real para que `readAsBytes`/`writeAsBytes` completen y
      // luego drena la microtask que continúa el flujo de la vista.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final ready = await tester.runAsync(
        () => localDb.select(localDb.progressPhotos).get(),
      );
      rows = ready ?? const [];
      if (rows.isNotEmpty) break;
    }

    expect(rows, hasLength(1));
    expect(rows.single.view, 'front');
    expect(File(rows.single.path).existsSync(), isTrue);
    expect(find.textContaining('No se pudo guardar'), findsNothing);
    handle.dispose();

    await unmount(tester);
  });

  testWidgets('tocar una tarjeta vacía abre la captura para esa vista',
      (tester) async {
    await pumpView(tester);
    await scrollToPhotos(tester);

    await tester.tap(find.text('FRENTE'));
    await settle(tester);

    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    // La vista ya está elegida por la tarjeta: no se pregunta.
    expect(find.widgetWithText(ListTile, 'Frente'), findsNothing);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await settle(tester);
    final rows = await tester.runAsync(
      () => localDb.select(localDb.progressPhotos).get(),
    );
    expect(rows, isEmpty);

    await unmount(tester);
  });

  testWidgets('la píldora abre el comparador con antes y después (RF-8)',
      (tester) async {
    await tester.runAsync(() async {
      await photoRepository.addPhoto(
        date: DateTime(2026, 1, 1),
        view: 'front',
        bytes: _tinyPng,
      );
      await photoRepository.addPhoto(
        date: DateTime(2026, 2, 1),
        view: 'front',
        bytes: _tinyPng,
      );
    });

    await pumpView(tester);
    await scrollToPhotos(tester);

    await tester.tap(find.text('1 ene vs 1 feb'));
    await settle(tester);

    expect(find.text('Comparar fotos'), findsOneWidget);
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Después'), findsOneWidget);
    expect(find.text('FRENTE'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('ESPALDA'), findsOneWidget);

    await unmount(tester);
  });

  Future<List<ProgressPhoto>> rowsAfter(
    WidgetTester tester,
    int expected,
  ) async {
    var rows = const <ProgressPhoto>[];
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final ready = await tester.runAsync(
        () => localDb.select(localDb.progressPhotos).get(),
      );
      rows = ready ?? const [];
      if (rows.length == expected) break;
    }
    return rows;
  }

  Future<void> seedTwoPhotos(WidgetTester tester) async {
    await tester.runAsync(() async {
      await photoRepository.addPhoto(
        date: DateTime(2026, 1, 1),
        view: 'front',
        bytes: _tinyPng,
      );
      await photoRepository.addPhoto(
        date: DateTime(2026, 2, 1),
        view: 'front',
        bytes: _tinyPng,
      );
    });
  }

  testWidgets('eliminar una foto desde el menú de la tarjeta (RF-10)',
      (tester) async {
    await seedTwoPhotos(tester);

    await pumpView(tester);
    await scrollToPhotos(tester);

    await tester.tap(find.byTooltip('Opciones de la foto').first);
    await settle(tester);
    expect(find.text('Ver foto'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await settle(tester);
    expect(find.text('¿Eliminar esta foto?'), findsOneWidget);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Eliminar'),
      ),
    );
    final rows = await rowsAfter(tester, 1);
    expect(rows, hasLength(1));
    await settle(tester);
    expect(find.text('Foto eliminada'), findsOneWidget);
    expect(find.text('1 feb'), findsNothing);
    expect(find.text('1 ene'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('eliminar todas las fotos pide confirmación (RF-11)',
      (tester) async {
    await tester.runAsync(() async {
      await photoRepository.addPhoto(
        date: DateTime(2026, 1, 1),
        view: 'front',
        bytes: _tinyPng,
      );
      await photoRepository.addPhoto(
        date: DateTime(2026, 2, 1),
        view: 'side',
        bytes: _tinyPng,
      );
    });

    await pumpView(tester);
    await scrollToPhotos(tester);

    expect(find.text('Eliminar todo'), findsOneWidget);
    await tester.tap(find.text('Eliminar todo'));
    await settle(tester);

    expect(find.text('¿Eliminar todas las fotos?'), findsOneWidget);
    expect(find.textContaining('2 fotos'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Eliminar todo'),
      ),
    );
    final rows = await rowsAfter(tester, 0);
    expect(rows, isEmpty);
    await settle(tester);
    expect(find.text('Fotos eliminadas'), findsOneWidget);
    expect(find.text('Eliminar todo'), findsNothing);

    await unmount(tester);
  });

  testWidgets(
      'el visor abre en la foto tocada, el contador avanza y permite borrar '
      '(RF-10 y RF-14)', (tester) async {
    await seedTwoPhotos(tester);

    await pumpView(tester);
    await scrollToPhotos(tester);

    await tester.tap(find.byTooltip('Opciones de la foto').first);
    await settle(tester);
    await tester.tap(find.text('Ver foto'));
    await settle(tester);
    await settle(tester);

    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await settle(tester);

    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar foto'));
    await settle(tester);
    expect(find.text('¿Eliminar esta foto?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Eliminar'),
      ),
    );
    final rows = await rowsAfter(tester, 1);
    expect(rows, hasLength(1));
    await settle(tester);

    expect(find.text('1 / 2'), findsNothing);
    expect(find.text('2 / 2'), findsNothing);
    expect(find.text('Foto eliminada'), findsOneWidget);

    await unmount(tester);
  });
}
