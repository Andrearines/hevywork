import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/custom_exercise.dart';
import 'package:hevywork/domain/custom_exercise_image.dart';

void main() {
  group('CustomExerciseDraft', () {
    CustomExerciseDraft valid() => const CustomExerciseDraft(
      name: '  Press propio  ',
      bodyPart: ' chest ',
      equipment: ' barbell ',
      target: ' pectorals ',
      secondaryMuscles: [' triceps ', 'shoulders'],
      restSeconds: 90,
    );

    test('recorta obligatorios, conserva orden y deriva muscle_group', () {
      final result = valid().validate();

      expect(result.name, 'Press propio');
      expect(result.bodyPart, 'chest');
      expect(result.equipment, 'barbell');
      expect(result.target, 'pectorals');
      expect(result.secondaryMuscles, ['triceps', 'deltoids']);
      expect(result.muscleGroup, 'triceps');
    });

    test('sin secundarios guarda lista vacía y deriva del objetivo', () {
      final result = valid().copyWith(secondaryMuscles: const []).validate();

      expect(result.secondaryMuscles, isEmpty);
      expect(result.muscleGroup, 'pectorals');
    });

    test('normaliza aliases y detecta equivalencias canónicas', () {
      final normalized = valid().copyWith(target: ' chest ').validate();
      expect(normalized.target, 'pectorals');
      final canonical = valid()
          .copyWith(
            target: 'biceps',
            secondaryMuscles: const ['chest', 'latissimus_dorsi'],
          )
          .validate();
      expect(canonical.secondaryMuscles, [
        'pectoralis_major',
        'latissimus_dorsi',
      ]);

      expect(
        () => valid()
            .copyWith(secondaryMuscles: const ['triceps', 'triceps'])
            .validate(),
        throwsA(isA<CustomExerciseValidationException>()),
      );
      expect(
        () => valid()
            .copyWith(target: 'delts', secondaryMuscles: const ['shoulders'])
            .validate(),
        throwsA(isA<CustomExerciseValidationException>()),
      );
    });

    test('valida obligatorios, vocabulario y límites de descanso', () {
      for (final invalid in [
        valid().copyWith(name: ' '),
        valid().copyWith(bodyPart: ' '),
        valid().copyWith(equipment: ' '),
        valid().copyWith(target: ' '),
        valid().copyWith(target: 'músculo inventado'),
        valid().copyWith(secondaryMuscles: const ['inventado']),
        valid().copyWith(restSeconds: 14),
        valid().copyWith(restSeconds: 301),
      ]) {
        expect(
          () => invalid.validate(),
          throwsA(isA<CustomExerciseValidationException>()),
        );
      }
      expect(valid().copyWith(restSeconds: 15).validate().restSeconds, 15);
      expect(valid().copyWith(restSeconds: 300).validate().restSeconds, 300);
    });
  });

  group('validateCustomImageBytes', () {
    final jpeg = Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xe0, 0xff, 0xd9]);
    final png = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1f,
      0x15,
      0xc4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4e,
      0x44,
      0xae,
      0x42,
      0x60,
      0x82,
    ]);
    final webp = Uint8List.fromList(const [
      0x52,
      0x49,
      0x46,
      0x46,
      0x04,
      0x00,
      0x00,
      0x00,
      0x57,
      0x45,
      0x42,
      0x50,
      0x56,
      0x50,
      0x38,
      0x20,
    ]);

    test('detecta MIME por firma y no por extensión', () {
      expect(validateCustomImageBytes(jpeg).mimeType, 'image/jpeg');
      expect(validateCustomImageBytes(png).mimeType, 'image/png');
      expect(validateCustomImageBytes(webp).mimeType, 'image/webp');
    });

    test('rechaza vacío, GIF, texto y formatos truncados', () {
      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList('GIF89a'.codeUnits),
        Uint8List.fromList('no soy una imagen'.codeUnits),
        Uint8List.fromList(jpeg.take(4).toList()),
        Uint8List.fromList(png.take(20).toList()),
      ]) {
        expect(
          () => validateCustomImageBytes(bytes),
          throwsA(isA<CustomImageValidationException>()),
        );
      }
    });

    test('acepta exactamente 2 MiB y rechaza un byte más', () {
      final maximum = Uint8List(2 * 1024 * 1024);
      maximum.setRange(0, jpeg.length, jpeg);
      maximum[maximum.length - 2] = 0xff;
      maximum[maximum.length - 1] = 0xd9;
      expect(validateCustomImageBytes(maximum).mimeType, 'image/jpeg');

      final excessive = Uint8List(2 * 1024 * 1024 + 1);
      excessive.setRange(0, jpeg.length, jpeg);
      excessive[excessive.length - 2] = 0xff;
      excessive[excessive.length - 1] = 0xd9;
      expect(
        () => validateCustomImageBytes(excessive),
        throwsA(isA<CustomImageValidationException>()),
      );
    });
  });
}
