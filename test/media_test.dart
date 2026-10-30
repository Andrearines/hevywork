import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/media.dart';

void main() {
  group('thumbAsset', () {
    test('prefija la ruta del dataset con assets/', () {
      expect(
        thumbAsset('images/0001-2gPfomN.jpg'),
        'assets/images/0001-2gPfomN.jpg',
      );
    });
  });

  group('gifUrl (RF-3)', () {
    test('sin URL configurada no hay GIF: la ficha usa la miniatura', () {
      expect(gifUrl('videos/0001-2gPfomN.gif'), isNull);
      expect(gifUrl('videos/0001-2gPfomN.gif', baseUrl: ''), isNull);
      expect(gifUrl(''), isNull);
    });

    test('construye la URL pública del bucket', () {
      expect(
        gifUrl('videos/0001-2gPfomN.gif', baseUrl: 'https://proyecto.supabase.co'),
        'https://proyecto.supabase.co/storage/v1/object/public/'
        'exercise-media/videos/0001-2gPfomN.gif',
      );
    });

    test('tolera la barra final en la URL base', () {
      expect(
        gifUrl('videos/a.gif', baseUrl: 'https://proyecto.supabase.co/'),
        'https://proyecto.supabase.co/storage/v1/object/public/'
        'exercise-media/videos/a.gif',
      );
    });
  });
}
