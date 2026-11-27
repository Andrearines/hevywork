import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/custom_exercise_repository.dart';
import 'package:hevywork/domain/custom_exercise.dart';
import 'package:hevywork/ui/views/custom_exercise_editor_view.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory documents;
  late CustomExerciseRepository repository;
  final imageBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    ),
  );

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

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('custom-save')));
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();
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

  testWidgets('guarda una imagen elegida en el repositorio local', (
    tester,
  ) async {
    final recording = _RecordingRepository(db, documents);
    await pumpEditor(
      tester,
      customRepository: recording,
      pickImage: (_) async => XFile.fromData(imageBytes, mimeType: 'image/png'),
    );
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-image-gallery')));
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await save(tester);

    expect(recording.imageBytes, imageBytes);
    expect(recording.draft?.name, 'Press propio');
    expect(recording.draft?.restSeconds, 135);
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
    await tester.pumpAndSettle();

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

  testWidgets('permite quitar una imagen recién elegida', (tester) async {
    await pumpEditor(
      tester,
      pickImage: (_) async => XFile.fromData(imageBytes, mimeType: 'image/png'),
    );
    await tester.tap(find.byKey(const Key('custom-image-gallery')));
    await tester.pumpAndSettle();
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

class _RecordingRepository extends CustomExerciseRepository {
  CustomExerciseDraft? draft;
  Uint8List? imageBytes;
  String? updatedId;
  bool removeImage = false;

  _RecordingRepository(super.db, Directory documents)
    : super(documentsDir: () async => documents);

  @override
  Future<Exercise> createCustomExercise({
    required CustomExerciseDraft draft,
    Uint8List? imageBytes,
  }) async {
    this.draft = draft;
    this.imageBytes = imageBytes;
    return _exercise('custom_recording', draft);
  }

  @override
  Future<Exercise> updateCustomExercise({
    required String id,
    required CustomExerciseDraft draft,
    Uint8List? imageBytes,
    bool removeImage = false,
  }) async {
    updatedId = id;
    this.draft = draft;
    this.imageBytes = imageBytes;
    this.removeImage = removeImage;
    return _exercise(id, draft);
  }

  Exercise _exercise(String id, CustomExerciseDraft draft) {
    final valid = draft.validate();
    return Exercise(
      id: id,
      name: valid.name,
      bodyPart: valid.bodyPart,
      equipment: valid.equipment,
      target: valid.target,
      muscleGroup: valid.muscleGroup,
      origin: 'custom',
      imageUploadStatus: 'none',
      updatedAt: DateTime(2026, 11, 26),
      restSeconds: valid.restSeconds,
    );
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
