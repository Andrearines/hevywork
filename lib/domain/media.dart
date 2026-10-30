import '../app_config.dart';

/// Bucket público de Supabase Storage con los GIFs del catálogo.
const String mediaBucket = 'exercise-media';

/// Ruta del asset empaquetado para una ruta de imagen del dataset.
String thumbAsset(String imagePath) => 'assets/$imagePath';

/// URL pública del GIF en Supabase Storage.
///
/// Devuelve `null` si no hay URL configurada: la app sigue funcionando en
/// local y la ficha muestra la miniatura (RF-3).
String? gifUrl(String gifPath, {String? baseUrl}) {
  if (gifPath.isEmpty) return null;
  final base = (baseUrl ?? supabaseUrl).trim();
  if (base.isEmpty) return null;
  final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$clean/storage/v1/object/public/$mediaBucket/$gifPath';
}
