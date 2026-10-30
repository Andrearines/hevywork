import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/search_text.dart';

void main() {
  group('normalizeSearchText (RF-1 de la 003)', () {
    test('minúsculas y sin acentos precompuestos', () {
      expect(normalizeSearchText('Press'), 'press');
      expect(normalizeSearchText('BÍCEPS'), 'biceps');
      expect(normalizeSearchText('barbéll'), 'barbell');
      expect(normalizeSearchText('café'), 'cafe');
      expect(normalizeSearchText('NÜÑEZ'), 'nunez');
    });

    test('las marcas combinantes (descompuestas) se descartan', () {
      expect(normalizeSearchText('bice\u0301ps'), 'biceps');
      expect(normalizeSearchText('b\u00E9isbol'), 'beisbol');
    });

    test('los espacios se colapsan y los bordes se recortan', () {
      expect(normalizeSearchText('  press   banca '), 'press banca');
      expect(normalizeSearchText('press\nbanca'), 'press banca');
    });

    test('texto vacío o solo espacios queda vacío', () {
      expect(normalizeSearchText(''), '');
      expect(normalizeSearchText('   '), '');
    });

    test('el texto ASCII se conserva tal cual en minúsculas', () {
      expect(normalizeSearchText('Zottman Curl'), 'zottman curl');
      expect(normalizeSearchText('e1RM 100%'), 'e1rm 100%');
    });
  });
}