import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/catalog_patches.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/domain/muscle_fatigue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> records;

  setUpAll(() async {
    final raw = await rootBundle.loadString(CatalogRepository.assetPath);
    records = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  });

  group('assets/exercises.json', () {
    test('tiene 1.324 ejercicios con el vocabulario 19/29/40', () {
      expect(records, hasLength(1324));
      expect(records.map((r) => r['target']).toSet(), hasLength(19));
      expect(records.map((r) => r['muscle_group']).toSet(), hasLength(29));
      expect(
        {
          for (final r in records)
            ...(r['secondary_muscles'] as List<dynamic>).cast<String>(),
        },
        hasLength(40),
      );
    });

    test('muscle_group es siempre el primer secundario', () {
      for (final r in records) {
        final secondary = (r['secondary_muscles'] as List<dynamic>);
        expect(
          r['muscle_group'],
          secondary.first,
          reason: 'ejercicio ${r['id']}',
        );
      }
    });

    test('el asset ya tiene aplicado kCatalogMusclePatches', () {
      final copy = [
        for (final record in records) Map<String, dynamic>.from(record),
      ];
      applyCatalogPatches(copy);
      expect(jsonEncode(copy), jsonEncode(records));
    });

    test('todo target del catálogo tiene zona en el mapa (salvo cardio)', () {
      final missing = <String>{};
      for (final r in records) {
        final target = r['target'] as String;
        if (target == 'cardiovascular system') continue;
        if (!kTargetMuscleAliases.containsKey(target)) missing.add(target);
      }
      expect(missing, isEmpty);
    });

    test('todo secundario del catálogo se puede dibujar en el mapa', () {
      final missing = <String>{};
      for (final r in records) {
        final secondary =
            (r['secondary_muscles'] as List<dynamic>).cast<String>();
        for (final muscle in secondary) {
          if (!kMuscleAliases.containsKey(muscle)) missing.add(muscle);
        }
      }
      expect(missing, isEmpty);
    });
  });
}
