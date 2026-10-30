import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Descarga los bytes de un GIF desde el bucket público. Se inyecta en los
/// tests para evitar la red (mismo patrón que `PhotoUploader`).
typedef GifDownloader = Future<Uint8List> Function(String gifPath);

/// Caché con nombre de los GIFs del catálogo (spec 001, RF-3): cada vez que
/// se abre una ficha, el GIF se descarga a `<soporte>/gifs/<id>.gif`; si ya
/// está, se sirve del disco sin re-descargar. Tras la primera vista el
/// ejercicio muestra su GIF sin conexión.
class GifCache {
  final GifDownloader? download;
  final Future<Directory> Function() cacheDir;

  GifCache({
    this.download,
    this.cacheDir = getApplicationSupportDirectory,
  });

  /// Ruta absoluta del fichero en caché de un ejercicio: `<gifs>/<id>.gif`.
  static String _pathOf(Directory base, String exerciseId) =>
      '${base.path}${Platform.pathSeparator}gifs'
      '${Platform.pathSeparator}$exerciseId.gif';

  /// Devuelve el GIF en disco, descargándolo desde el bucket si aún no está
  /// cacheado. `null` si no hay ruta de GIF, no hay descargador o esta falla
  /// (sin red): la ficha muestra entonces la miniatura local.
  Future<File?> ensureCached({
    required String exerciseId,
    required String gifPath,
  }) async {
    if (gifPath.isEmpty) return null;
    final file = File(_pathOf(await cacheDir(), exerciseId));
    if (file.existsSync()) return file;
    final download = this.download;
    if (download == null) return null;
    try {
      final bytes = await download(gifPath);
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }
}
