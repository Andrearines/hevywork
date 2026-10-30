// Genera assets/exercises.json y empaqueta las miniaturas del clon local de
// exercises-dataset. Uso: dart run tool/build_catalog_asset.dart
import 'dart:convert';
import 'dart:io';

const _sourceFields = [
  'id',
  'name',
  'body_part',
  'equipment',
  'target',
  'muscle_group',
  'secondary_muscles',
  'media_id',
  'image',
  'gif_url',
  'attribution',
  'created_at',
];

const _languages = ['es', 'en'];

void main() {
  final scriptRoot = File.fromUri(Platform.script).parent.parent.path;
  final root = [
    Directory.current.path,
    scriptRoot,
  ].firstWhere(
    (path) => File('$path/exercises-dataset/data/exercises.json').existsSync(),
    orElse: () => Directory.current.path,
  );
  final source = File('$root/exercises-dataset/data/exercises.json');
  final target = File('$root/assets/exercises.json');

  if (!source.existsSync()) {
    stderr.writeln(
      'No se encuentra ${source.path}. Clona el dataset antes de generar el asset.',
    );
    exitCode = 1;
    return;
  }

  final records = jsonDecode(source.readAsStringSync()) as List<dynamic>;
  final trimmed = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  for (final raw in records) {
    final item = raw as Map<String, dynamic>;
    final id = item['id'] as String;
    if (!seenIds.add(id)) {
      stderr.writeln('id duplicado: $id');
      exitCode = 1;
      return;
    }

    final steps = item['instruction_steps'] as Map<String, dynamic>;
    final localizedSteps = <String, dynamic>{
      for (final lang in _languages) lang: steps[lang],
    };
    if (localizedSteps.values.any((value) => value == null)) {
      stderr.writeln('Faltan pasos de instrucción en $id');
      exitCode = 1;
      return;
    }

    final entry = <String, dynamic>{
      for (final field in _sourceFields) field: item[field],
      'instruction_steps': localizedSteps,
    };
    trimmed.add(entry);
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(jsonEncode(trimmed));

  final copied = _syncThumbnails(root, trimmed);
  if (exitCode != 0) return;

  final kb = (target.lengthSync() / 1024).toStringAsFixed(0);
  stdout.writeln(
    'Asset generado: ${target.path} — ${trimmed.length} ejercicios, $kb KB, '
    'idiomas: ${_languages.join(', ')}',
  );
  stdout.writeln(
    'Miniaturas empaquetadas: ${trimmed.length} en assets/images/ '
    '($copied copiadas en esta ejecución)',
  );
}

/// Copia las miniaturas del dataset a assets/images/ y elimina las huérfanas.
int _syncThumbnails(String root, List<Map<String, dynamic>> records) {
  final expected = <String>{};
  var copied = 0;

  for (final record in records) {
    final imagePath = record['image'] as String?;
    if (imagePath == null || imagePath.isEmpty) {
      stderr.writeln('Falta la miniatura del ejercicio ${record['id']}');
      exitCode = 1;
      return copied;
    }

    final name = imagePath.split('/').last;
    expected.add(name);

    final from = File('$root/exercises-dataset/$imagePath');
    final to = File('$root/assets/$imagePath');
    if (!from.existsSync()) {
      stderr.writeln('No existe ${from.path}');
      exitCode = 1;
      return copied;
    }

    if (!to.existsSync() || to.lengthSync() != from.lengthSync()) {
      to.parent.createSync(recursive: true);
      from.copySync(to.path);
      copied++;
    }
  }

  final targetDir = Directory('$root/assets/images');
  if (targetDir.existsSync()) {
    for (final file in targetDir.listSync().whereType<File>()) {
      if (!expected.contains(file.uri.pathSegments.last)) {
        file.deleteSync();
      }
    }
  }

  return copied;
}
