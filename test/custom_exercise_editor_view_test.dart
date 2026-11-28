import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/custom_exercise_repository.dart';
import 'package:hevywork/domain/custom_exercise.dart';
import 'package:hevywork/ui/views/custom_exercise_editor_view.dart';
import 'package:image_picker/image_picker.dart';

import 'custom_image_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory documents;
  late CustomExerciseRepository repository;
  final imageBytes = validPngImageBytes();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = Directory(
      '/tmp/opencode/hevywork-t004/editor-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    await documents.create(recursive: true);
    repository = CustomExerciseRepository(
      db,
      documentsDir: () async => documents,
    );
  });

  tearDown(() async {
    await db.close();
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    Exercise? exercise,
    CustomExerciseRepository? customRepository,
    CustomExerciseImagePicker? pickImage,
    double width = 375,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: CustomExerciseEditorView(
          repository: customRepository ?? repository,
          exercise: exercise,
          pickImage: pickImage,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), value);
  }

  Future<void> chooseTarget(WidgetTester tester, String target) async {
    await tester.ensureVisible(find.byKey(const Key('custom-target')));
    await tester.tap(find.byKey(const Key('custom-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target).last);
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    await enter(tester, const Key('custom-name'), 'Press propio');
    await chooseTarget(tester, 'pectorals');
    await tester.ensureVisible(
      find.byKey(const Key('custom-secondary-triceps')),
    );
    await tester.tap(find.byKey(const Key('custom-secondary-triceps')));
    await enter(tester, const Key('custom-body-part'), 'chest');
    await enter(tester, const Key('custom-equipment'), 'barbell');
    await enter(tester, const Key('custom-rest'), '135');
  }

  Future<void> save(WidgetTester tester, {bool realAsync = false}) async {
    await tester.ensureVisible(find.byKey(const Key('custom-save')));
    if (realAsync) {
      bool saving() {
        final button = find.byKey(const Key('custom-save'));
        return button.evaluate().isNotEmpty &&
            tester.widget<ElevatedButton>(button).onPressed == null;
      }

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('custom-save')));
        await tester.pump();
      });
      while ((await db.select(db.exercises).get()).isEmpty && saving()) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pump();
      return;
    }
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();
  }

  Future<void> settlePicker(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('valida obligatorios y conserva el borrador', (tester) async {
    await pumpEditor(tester);
    await enter(tester, const Key('custom-name'), 'Borrador conservado');
    await save(tester);

    expect(find.text('Escribe la parte del cuerpo'), findsOneWidget);
    expect(find.text('Escribe el equipo'), findsOneWidget);
    expect(find.text('Selecciona el músculo objetivo'), findsOneWidget);
    expect(find.text('Borrador conservado'), findsOneWidget);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  testWidgets('crea un ejercicio completo sin imagen y sin red', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(
      (tester
              .widget<TextFormField>(find.byKey(const Key('custom-rest')))
              .controller!)
          .text,
      '90',
    );
    expect(find.text('Se sincronizará cuando haya conexión'), findsOneWidget);
    await fillValid(tester);
    await save(tester);

    final saved = await db.select(db.exercises).getSingle();
    expect(saved.name, 'Press propio');
    expect(saved.target, 'pectorals');
    expect(saved.muscleGroup, 'triceps');
    expect(saved.restSeconds, 135);
    expect(saved.imagePath, isNull);
    expect(saved.origin, 'custom');
    expect(saved.imageUploadStatus, 'none');
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  testWidgets('guarda una imagen de galería real en el repositorio local', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      pickImage: (_) async => XFile.fromData(imageBytes, mimeType: 'image/png'),
    );
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-image-gallery')));
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await settlePicker(tester);
    expect(find.byType(Image), findsOneWidget);
    await save(tester, realAsync: true);

    final saved = await db.select(db.exercises).getSingle();
    expect(saved.name, 'Press propio');
    expect(saved.restSeconds, 135);
    expect(saved.imageMimeType, 'image/png');
    expect(saved.imageUploadStatus, 'pending_upload');
    expect(File(saved.imagePath!).readAsBytesSync(), imageBytes);
  });

  testWidgets('guarda una captura WebP válida desde cámara', (tester) async {
    ImageSource? selectedSource;
    final webp = validWebpImageBytes();
    await pumpEditor(
      tester,
      pickImage: (source) async {
        selectedSource = source;
        return XFile.fromData(webp, mimeType: 'image/webp');
      },
    );
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-image-camera')));
    await tester.tap(find.byKey(const Key('custom-image-camera')));
    await settlePicker(tester);
    await save(tester, realAsync: true);

    final saved = await db.select(db.exercises).getSingle();
    expect(selectedSource, ImageSource.camera);
    expect(saved.imageMimeType, 'image/webp');
    expect(saved.imageUploadStatus, 'pending_upload');
    expect(File(saved.imagePath!).readAsBytesSync(), webp);
  });

  testWidgets('cancelar el picker conserva el borrador sin imagen nueva', (
    tester,
  ) async {
    await pumpEditor(tester, pickImage: (_) async => null);
    await enter(tester, const Key('custom-name'), 'Borrador conservado');
    await tester.ensureVisible(find.byKey(const Key('custom-image-gallery')));
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await settlePicker(tester);

    expect(find.text('Borrador conservado'), findsOneWidget);
    expect(find.byKey(const Key('custom-image-error')), findsNothing);
    expect(find.byKey(const Key('custom-image-remove')), findsNothing);
  });

  testWidgets('cámara no disponible conserva el borrador', (tester) async {
    await pumpEditor(
      tester,
      pickImage: (_) async =>
          throw PlatformException(code: 'camera_unavailable'),
    );
    await enter(tester, const Key('custom-name'), 'Borrador de cámara');
    await tester.ensureVisible(find.byKey(const Key('custom-image-camera')));
    await tester.tap(find.byKey(const Key('custom-image-camera')));
    await settlePicker(tester);

    expect(find.byKey(const Key('custom-image-error')), findsOneWidget);
    expect(find.text('Borrador de cámara'), findsOneWidget);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  testWidgets('IOException al leer conserva el borrador y la selección', (
    tester,
  ) async {
    final missing =
        '/tmp/opencode/hevywork-t004-iter1/missing-editor-image.jpg';
    await pumpEditor(tester, pickImage: (_) async => XFile(missing));
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-image-gallery')));
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await settlePicker(tester);

    expect(find.byKey(const Key('custom-image-error')), findsOneWidget);
    expect(find.text('Press propio'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('custom-secondary-triceps')))
          .selected,
      isTrue,
    );
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  testWidgets('permiso denegado muestra error y no pierde campos ni imagen', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      pickImage: (_) async => throw StateError('denied'),
    );
    await enter(tester, const Key('custom-name'), 'Mi borrador');
    await tester.ensureVisible(find.byKey(const Key('custom-image-camera')));
    await tester.tap(find.byKey(const Key('custom-image-camera')));
    await settlePicker(tester);

    expect(find.byKey(const Key('custom-image-error')), findsOneWidget);
    expect(find.text('Mi borrador'), findsOneWidget);
    expect(find.text('Guardar ejercicio'), findsOneWidget);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  testWidgets('edita los campos de un ejercicio existente', (tester) async {
    final created = await repository.createCustomExercise(
      draft: const CustomExerciseDraft(
        name: 'Original',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        secondaryMuscles: ['triceps'],
        restSeconds: 120,
      ),
    );
    await pumpEditor(tester, exercise: created);
    expect(find.text('Editar ejercicio'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    await enter(tester, const Key('custom-name'), 'Editado');
    await save(tester);

    final saved = await db.select(db.exercises).getSingle();
    expect(saved.id, created.id);
    expect(saved.name, 'Editado');
    expect(saved.restSeconds, 120);
  });

  testWidgets(
    'archivo inválido conserva borrador e imagen anterior al guardar',
    (tester) async {
      final created = await tester.runAsync(
        () => repository.createCustomExercise(
          draft: const CustomExerciseDraft(
            name: 'Original',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            secondaryMuscles: ['triceps'],
            restSeconds: 120,
          ),
          imageBytes: imageBytes,
        ),
      );
      final oldPath = created!.imagePath!;
      final corrupt = Uint8List.fromList(const [
        0xff,
        0xd8,
        0xff,
        0xe0,
        0xff,
        0xd9,
      ]);
      await pumpEditor(
        tester,
        exercise: created,
        pickImage: (_) async => XFile.fromData(corrupt),
      );
      await enter(tester, const Key('custom-name'), 'Borrador conservado');
      await tester.ensureVisible(find.byKey(const Key('custom-image-gallery')));
      await tester.tap(find.byKey(const Key('custom-image-gallery')));
      await settlePicker(tester);

      expect(
        find.text('Elige una imagen JPEG, PNG o WebP válida'),
        findsOneWidget,
      );
      await save(tester);
      final saved = await db.select(db.exercises).getSingle();
      expect(saved.name, 'Borrador conservado');
      expect(saved.imagePath, oldPath);
      expect(saved.imageUploadStatus, 'pending_upload');
      expect(File(oldPath).readAsBytesSync(), imageBytes);
    },
  );

  testWidgets(
    'equivalencia con el objetivo muestra error junto a secundarios',
    (tester) async {
      await pumpEditor(tester);
      await fillValid(tester);
      await tester.ensureVisible(
        find.byKey(const Key('custom-secondary-chest')),
      );
      await tester.tap(find.byKey(const Key('custom-secondary-chest')));
      await save(tester);

      expect(find.byKey(const Key('custom-secondary-error')), findsOneWidget);
      expect(find.byKey(const Key('custom-save-error')), findsNothing);
      expect(
        find.text('No repitas el objetivo ni los músculos secundarios'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('custom-secondary-chest')))
            .selected,
        isTrue,
      );
      expect(find.text('Press propio'), findsOneWidget);
      expect(find.text('135'), findsOneWidget);
      expect(await db.select(db.exercises).get(), isEmpty);
    },
  );

  testWidgets(
    'duplicados canónicos muestran error inline y conservan selección',
    (tester) async {
      await pumpEditor(tester);
      await fillValid(tester);
      await chooseTarget(tester, 'lats');
      for (final muscle in ['chest', 'pectoralis_major']) {
        await tester.ensureVisible(find.byKey(Key('custom-secondary-$muscle')));
        await tester.tap(find.byKey(Key('custom-secondary-$muscle')));
      }
      await save(tester);

      expect(find.byKey(const Key('custom-secondary-error')), findsOneWidget);
      expect(find.byKey(const Key('custom-save-error')), findsNothing);
      for (final muscle in ['chest', 'pectoralis_major']) {
        expect(
          tester
              .widget<FilterChip>(find.byKey(Key('custom-secondary-$muscle')))
              .selected,
          isTrue,
        );
      }
      expect(await db.select(db.exercises).get(), isEmpty);
    },
  );

  testWidgets('permite quitar una imagen recién elegida', (tester) async {
    await pumpEditor(
      tester,
      pickImage: (_) async => XFile.fromData(imageBytes, mimeType: 'image/png'),
    );
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await settlePicker(tester);
    expect(find.byKey(const Key('custom-image-remove')), findsOneWidget);
    await tester.tap(find.byKey(const Key('custom-image-remove')));
    await tester.pump();
    expect(find.byKey(const Key('custom-image-remove')), findsNothing);
  });

  testWidgets('el CTA bloquea altas duplicadas durante el guardado', (
    tester,
  ) async {
    final delayed = _DelayedRepository(db, documents);
    addTearDown(() {
      if (!delayed.gate.isCompleted) delayed.gate.complete();
    });
    await pumpEditor(tester, customRepository: delayed);
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-save')));
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom-save')), warnIfMissed: false);
    await tester.pump();

    expect(delayed.calls, 1);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('custom-save')))
          .onPressed,
      isNull,
    );
    delayed.gate.complete();
    await tester.pumpAndSettle();
    expect(await db.select(db.exercises).get(), hasLength(1));
  });

  for (final width in [320.0, 375.0, 640.0, 1024.0]) {
    testWidgets('editor usable a $width dp con textScaler 1.3', (tester) async {
      await pumpEditor(tester, width: width, textScale: 1.3);
      expect(tester.takeException(), isNull);
      for (final key in [
        const Key('custom-image-gallery'),
        const Key('custom-image-camera'),
        const Key('custom-save'),
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(44),
        );
      }
      await tester.ensureVisible(find.byKey(const Key('custom-save')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

class _DelayedRepository extends CustomExerciseRepository {
  final Completer<void> gate = Completer<void>();
  int calls = 0;

  _DelayedRepository(super.db, Directory documents)
    : super(documentsDir: () async => documents);

  @override
  Future<Exercise> createCustomExercise({
    required CustomExerciseDraft draft,
    Uint8List? imageBytes,
  }) async {
    calls++;
    await gate.future;
    return super.createCustomExercise(draft: draft, imageBytes: imageBytes);
  }
}
