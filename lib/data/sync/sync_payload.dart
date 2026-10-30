import 'dart:convert';

/// Columnas que existen en Postgres para cada tabla sincronizable (RF-13).
///
/// El payload encolado puede traer columnas locales que no existen en el
/// remoto (`name`, `rest_ends_at`…): se descartan aquí para que el upsert
/// no falle con una columna desconocida.
const Map<String, Set<String>> remoteColumns = {
  'profiles': {'display_name', 'unit_system', 'sex', 'height_cm'},
  'workouts': {
    'id',
    'user_id',
    'routine_id',
    'name',
    'status',
    'started_at',
    'ended_at',
    'notes',
    'client_updated_at',
  },
  'workout_exercises': {
    'id',
    'user_id',
    'workout_id',
    'exercise_id',
    'order_index',
    'target_sets',
    'target_reps',
    'target_rir',
    'suggested_weight_kg',
    'notes',
  },
  'workout_sets': {
    'id',
    'user_id',
    'workout_exercise_id',
    'routine_set_id',
    'order_index',
    'set_type',
    'reps',
    'weight_kg',
    'rir',
    'rest_seconds',
    'completed',
  },
  'routines': {
    'id',
    'user_id',
    'name',
    'description',
    'category',
    'level',
    'goal',
    'target_days',
  },
  'routine_exercises': {
    'id',
    'user_id',
    'routine_id',
    'exercise_id',
    'order_index',
    'target_sets',
    'target_reps',
    'target_rir',
    'suggested_weight_kg',
    'auto_progress',
  },
  'routine_sets': {
    'id',
    'user_id',
    'routine_exercise_id',
    'order_index',
    'set_type',
    'weight_kg',
    'reps',
    'rir',
    'rest_seconds',
  },
  'goals': {
    'id',
    'user_id',
    'type',
    'target_value',
    'deadline',
    'period',
    'metric_ref',
    'status',
    'current_value',
  },
  'body_metrics': {
    'user_id',
    'date',
    'weight_kg',
    'body_fat_pct',
    'lean_mass_kg',
    'measures_json',
    'notes',
  },
  'progress_photos': {'id', 'user_id', 'date', 'view', 'path'},
};

/// Convierte el payload encolado en la fila que Postgres espera (RF-13).
///
/// - Añade `user_id` (o `id = auth.uid()` en `profiles`) exigido por RLS.
/// - `created_at`/`updated_at` son del servidor: no se mandan.
/// - Las fechas deben ir como ISO-8601 en el payload.
Map<String, dynamic> buildRemoteRow({
  required String table,
  required String payloadJson,
  required String userId,
}) {
  final columns = remoteColumns[table];
  if (columns == null) {
    throw StateError('Tabla sincronizable desconocida: $table');
  }

  final payload = jsonDecode(payloadJson);
  if (payload is! Map<String, dynamic>) {
    throw StateError('El payload de $table no es un objeto JSON');
  }

  final row = <String, dynamic>{
    for (final entry in payload.entries)
      if (columns.contains(entry.key) &&
          // En el perfil el nulo es un valor: borrar el nombre, el sexo o la
          // altura debe propagarse al remoto, no quedarse con el anterior.
          (entry.value != null || table == 'profiles'))
        entry.key: entry.value,
  };

  if (table == 'body_metrics') {
    // Clave compuesta (user_id, date): el payload no trae `id`, pero debe
    // traer la fecha civil en ISO.
    if (row['date'] == null) {
      throw StateError('El payload de $table no trae date');
    }
  } else if (table != 'profiles' && row['id'] == null) {
    throw StateError('El payload de $table no trae id');
  }

  // `profiles` se identifica por el uuid de auth (PK `id`); el resto de
  // tablas llevan `user_id` para RLS.
  if (table == 'profiles') {
    row['id'] = userId;
  } else {
    row['user_id'] = userId;
  }

  if (table == 'progress_photos') {
    // El objeto vive en la carpeta del usuario autenticado (política del
    // bucket): la clave se deriva siempre de `user_id` real, no del id
    // local, que puede diferir tras el claim.
    row['path'] = '${row['user_id']}/${row['id']}.jpg';
  }

  if (table == 'workouts') {
    final clientTimestamp =
        payload['client_updated_at'] ?? payload['updated_at'];
    if (clientTimestamp != null) {
      row['client_updated_at'] = clientTimestamp;
    }
  }

  if (table == 'workout_sets') {
    row['rir'] = payload['rir'] ?? 0;
    row['weight_kg'] = payload['weight_kg'] ?? 0;
  }

  return row;
}
