// Sube los GIFs del dataset al bucket exercise-media de Supabase Storage.
// Uso: dart run tool/upload_gifs.dart  (lee SUPABASE_URL y SUPABASE_SECRET_KEY de .env)
import 'dart:convert';
import 'dart:io';

const String _bucket = 'exercise-media';
const int _concurrency = 8;
const int _maxAttempts = 3;

Future<void> main() async {
  final root = _projectRoot();
  final source = File('$root/exercises-dataset/data/exercises.json');
  if (!source.existsSync()) {
    stderr.writeln('No se encuentra ${source.path}. Clona el dataset antes de subir.');
    exitCode = 1;
    return;
  }

  final env = _readEnv('$root/.env');
  final url = env['SUPABASE_URL'];
  final key = env['SUPABASE_SECRET_KEY'];
  if (url == null || key == null) {
    stderr.writeln('Falta SUPABASE_URL o SUPABASE_SECRET_KEY en .env');
    exitCode = 1;
    return;
  }

  final records = jsonDecode(source.readAsStringSync()) as List<dynamic>;
  final paths = records
      .map((r) => (r as Map<String, dynamic>)['gif_url'] as String)
      .toSet()
      .toList();

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 60);

  final existing = await _listExisting(client, url, key);
  final pending = paths.where((p) => !existing.contains(p)).toList();

  stdout.writeln(
    'GIFs en el dataset: ${paths.length} — ya subidos: ${existing.length} — '
    'pendientes: ${pending.length}',
  );

  var uploaded = 0;
  var failed = 0;
  var cursor = 0;

  Future<void> worker() async {
    while (true) {
      final index = cursor++;
      if (index >= pending.length) return;
      final path = pending[index];

      final ok = await _upload(client, url, key, path);
      if (ok) {
        uploaded++;
      } else {
        failed++;
        stderr.writeln('No se pudo subir $path');
      }

      final done = uploaded + failed;
      if (done % 100 == 0) {
        stdout.writeln('  … $done/${pending.length}');
      }
    }
  }

  await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
  client.close(force: true);

  stdout.writeln(
    'Subida completada: $uploaded subidos, ${existing.length} ya estaban, '
    '$failed fallos.',
  );
  if (uploaded > 0) {
    stdout.writeln(
      'Comprueba: $url/storage/v1/object/public/$_bucket/${pending.first}',
    );
  }
  if (failed > 0) exitCode = 1;
}

String _projectRoot() {
  final scriptRoot = File.fromUri(Platform.script).parent.parent.path;
  return [
    Directory.current.path,
    scriptRoot,
  ].firstWhere(
    (path) => File('$path/exercises-dataset/data/exercises.json').existsSync(),
    orElse: () => Directory.current.path,
  );
}

Map<String, String> _readEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    env[trimmed.substring(0, index)] = trimmed.substring(index + 1).trim();
  }
  return env;
}

Future<Set<String>> _listExisting(
  HttpClient client,
  String url,
  String key,
) async {
  final existing = <String>{};
  var offset = 0;

  try {
    while (true) {
      final request = await client.postUrl(
        Uri.parse('$url/storage/v1/object/list/$_bucket'),
      );
      request.headers
        ..set('Authorization', 'Bearer $key')
        ..set('apikey', key)
        ..set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'prefix': 'videos',
        'limit': 100,
        'offset': offset,
      }));

      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return existing;
      }
      final body = await response.transform(utf8.decoder).join();
      final entries = jsonDecode(body) as List<dynamic>;
      if (entries.isEmpty) break;

      for (final entry in entries.cast<Map<String, dynamic>>()) {
        final name = entry['name'] as String?;
        if (name == null || entry['id'] == null) continue; // carpetas
        existing.add('videos/$name');
      }

      if (entries.length < 100) break;
      offset += 100;
    }
  } catch (_) {
    return existing;
  }

  return existing;
}

Future<bool> _upload(
  HttpClient client,
  String url,
  String key,
  String path,
) async {
  final file = File('${_projectRoot()}/exercises-dataset/$path');
  if (!file.existsSync()) return false;
  final bytes = await file.readAsBytes();

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    try {
      final request = await client.postUrl(
        Uri.parse('$url/storage/v1/object/$_bucket/$path'),
      );
      request.headers
        ..set('Authorization', 'Bearer $key')
        ..set('apikey', key)
        ..set('Content-Type', 'image/gif')
        ..set('x-upsert', 'false');
      request.add(bytes);

      final response = await request.close();
      await response.drain<void>();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      if (response.statusCode == 409) {
        return true; // Ya existía: la subida es idempotente.
      }
    } catch (_) {
      // Reintenta con backoff.
    }
    await Future<void>.delayed(Duration(seconds: attempt));
  }

  return false;
}
