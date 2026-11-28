import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/custom_exercise.dart';
import 'package:hevywork/domain/custom_exercise_image.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

import 'custom_image_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(result.muscleGroup, 'pectoralis_major');
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

    const canonicalTargets = {
      'abdominals': 'abs',
      'biceps': 'biceps',
      'calves': 'calves',
      'deltoids': 'delts',
      'forearms': 'forearms',
      'glutes': 'glutes',
      'hamstrings': 'hamstrings',
      'latissimus_dorsi': 'lats',
      'lower_back': 'spine',
      'obliques': 'serratus anterior',
      'pectoralis_major': 'pectorals',
      'quadriceps': 'quads',
      'rhomboids': 'upper back',
      'trapezius': 'traps',
      'triceps': 'triceps',
    };

    test('el barrido incluye todos los canónicos de objetivo reconocidos', () {
      expect(
        canonicalTargets.keys.toSet(),
        kTargetMuscleAliases.values.toSet(),
      );
    });

    for (final entry in canonicalTargets.entries) {
      test('acepta el objetivo canónico ${entry.key} de forma idempotente', () {
        final result = valid()
            .copyWith(target: entry.key, secondaryMuscles: const [])
            .validate();

        expect(result.target, entry.value);
        expect(result.muscleGroup, entry.key);
        final repeated = valid()
            .copyWith(target: result.target, secondaryMuscles: const [])
            .validate();
        expect(repeated.target, result.target);
        expect(repeated.muscleGroup, result.muscleGroup);
      });
    }

    for (final target in customExerciseTargets) {
      test(
        '$target sin secundarios deriva grupo filtrable y fatiga segura',
        () {
          final result = valid()
              .copyWith(target: target, secondaryMuscles: const [])
              .validate();
          expect(result.muscleGroup.trim(), isNotEmpty);

          final sets = <FatigueSet>[
            (
              endedAt: DateTime(2026, 11, 27, 12),
              volume: 1000,
              setType: 'normal',
              target: result.target,
              secondaryMuscles: result.secondaryMuscles,
            ),
          ];
          final now = DateTime(2026, 11, 27, 12);
          final raw = rawMuscleFatigue(now: now, sets: sets);
          final roles = muscleRoles(now: now, sets: sets);
          final fatigue = muscleFatigue(now: now, sets: sets);
          if (target == 'cardiovascular system') {
            expect(result.muscleGroup, 'cardiovascular system');
            expect(raw, isEmpty);
            expect(roles.primary, isEmpty);
            expect(fatigue, isEmpty);
          } else {
            expect(raw[result.muscleGroup], 1000);
            expect(roles.primary[result.muscleGroup], 0);
            expect(fatigue[result.muscleGroup], kHighValue);
          }
        },
      );
    }

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

  group('canonical muscles in fatigue', () {
    test(
      'los canónicos persistidos conservan primario, secundarios y mapa',
      () {
        final now = DateTime(2026, 10, 9, 12);
        final sets = <FatigueSet>[
          (
            endedAt: now,
            volume: 1000,
            setType: 'normal',
            target: 'pectoralis_major',
            secondaryMuscles: const ['latissimus_dorsi', 'lower_back'],
          ),
        ];

        final raw = rawMuscleFatigue(now: now, sets: sets);
        expect(raw['pectoralis_major'], 1000);
        expect(raw['latissimus_dorsi'], 500);
        expect(raw['lower_back'], 500);

        final roles = muscleRoles(now: now, sets: sets);
        expect(roles.primary['pectoralis_major'], 0);
        expect(roles.secondary['latissimus_dorsi'], 0);
        expect(roles.secondary['lower_back'], 0);

        final fatigue = muscleFatigue(now: now, sets: sets);
        expect(fatigue['pectoralis_major'], kHighValue);
        expect(fatigue['latissimus_dorsi'], kOptimalValue);
        expect(fatigue['lower_back'], kOptimalValue);
      },
    );
  });

  group('validateCustomImageBytes', () {
    Future<ValidatedCustomImage> validate(Uint8List bytes) =>
        Future.sync(() => validateCustomImageBytes(bytes));

    test('detecta imágenes reales JPEG, PNG y WebP por sus bytes', () async {
      expect((await validate(validJpegImageBytes())).mimeType, 'image/jpeg');
      expect((await validate(validPngImageBytes())).mimeType, 'image/png');
      expect((await validate(validWebpImageBytes())).mimeType, 'image/webp');
    });

    test(
      'rechaza estructuras con firma válida que no son decodificables',
      () async {
        final pngWithoutIdat = Uint8List.fromList([
          ...validPngImageBytes().take(33),
          ...validPngImageBytes().skip(validPngImageBytes().length - 12),
        ]);
        final pngWithBadCrc = validPngImageBytes();
        pngWithBadCrc[29] ^= 0x01;
        final cases = <String, Uint8List>{
          'JPEG solo con SOI y EOI': Uint8List.fromList(const [
            0xff,
            0xd8,
            0xff,
            0xe0,
            0xff,
            0xd9,
          ]),
          'PNG sin IDAT': pngWithoutIdat,
          'PNG con CRC inválido': pngWithBadCrc,
          'WebP sin payload': Uint8List.fromList(const [
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
          ]),
        };

        for (final entry in cases.entries) {
          await expectLater(
            validate(entry.value),
            throwsA(isA<CustomImageValidationException>()),
            reason: entry.key,
          );
        }
      },
    );

    test('rechaza vacío, GIF, texto y formatos truncados', () async {
      final jpeg = validJpegImageBytes();
      final png = validPngImageBytes();
      final webp = validWebpImageBytes();
      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList('GIF89a'.codeUnits),
        Uint8List.fromList('no soy una imagen'.codeUnits),
        Uint8List.fromList(jpeg.take(4).toList()),
        Uint8List.fromList(png.take(20).toList()),
        Uint8List.fromList(webp.take(20).toList()),
      ]) {
        await expectLater(
          validate(bytes),
          throwsA(isA<CustomImageValidationException>()),
        );
      }
    });

    test('acepta exactamente 2 MiB y rechaza un byte más', () async {
      final jpeg = validJpegImageBytes();
      final maximum = Uint8List(customExerciseImageMaxBytes);
      maximum.setRange(0, jpeg.length, jpeg);
      maximum[maximum.length - 2] = 0xff;
      maximum[maximum.length - 1] = 0xd9;
      expect((await validate(maximum)).mimeType, 'image/jpeg');

      final excessive = Uint8List(customExerciseImageMaxBytes + 1);
      excessive.setRange(0, jpeg.length, jpeg);
      excessive[excessive.length - 2] = 0xff;
      excessive[excessive.length - 1] = 0xd9;
      await expectLater(
        validate(excessive),
        throwsA(
          isA<CustomImageValidationException>().having(
            (error) => error.message,
            'message',
            'La imagen no puede superar 2 MB',
          ),
        ),
      );
    });
  });
}
