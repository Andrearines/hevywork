import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import 'sync_payload.dart';

/// Sube una fila ya mapeada a Supabase. Se inyecta en los tests.
typedef SyncPusher = Future<void> Function(
  String table,
  String operation,
  Map<String, dynamic> row,
);

class SyncEngine {
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  final StreamController<String> _notices =
      StreamController<String>.broadcast();

  /// Inyectable en los tests para evitar la red.
  final SyncPusher? pusher;

  /// Proveedor de `user_id`. Por defecto sale de la sesión de Supabase.
  final String? Function()? userIdProvider;

  /// Se invoca tras un ciclo de sync que haya subido al menos un cambio
  /// (spec 007, RF-6): recálculo del cache de fatiga.
  final Future<void> Function()? onSyncCompleted;

  /// Se invoca al final de cada ciclo con sesión (spec 009, RF-7): subida
  /// de las fotos de progreso pendientes.
  final Future<void> Function()? onCycleCompleted;

  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncEngine(
    this._db,
    this._supabase, {
    this.pusher,
    this.userIdProvider,
    this.onSyncCompleted,
    this.onCycleCompleted,
  });

  /// Avisos para el usuario (toast): RF-15, dead_letter.
  Stream<String> get notices => _notices.stream;

  /// Inicia el motor de sincronización (se llama al arrancar la app)
  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processQueue();
    });
    processQueue();
  }

  void stop() {
    _syncTimer?.cancel();
  }

  /// Procesa la cola local FIFO (RF-12).
  Future<void> processQueue() async {
    if (_isSyncing) return;

    final pusher = this.pusher;
    if (pusher == null && _supabase == null) return;

    final session = _supabase?.auth.currentSession;
    // Sin sesión no se consume ningún intento: el login es diferido (RF-16).
    if (pusher == null && session == null) return;

    final userId = session?.user.id ?? userIdProvider?.call();
    if (userId == null) return;

    final doPush = pusher ?? _pushToSupabase;
    _isSyncing = true;

    try {
      final query = _db.select(_db.syncQueue)
        ..where((t) => t.status.equals('pending'))
        ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(DateTime.now()))
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
        ])
        ..limit(50);

      var pushed = 0;
      for (final item in await query.get()) {
        try {
          final row = buildRemoteRow(
            table: item.targetTable,
            payloadJson: item.payload,
            userId: userId,
          );
          await doPush(item.targetTable, item.operation, row);
          await (_db.delete(
            _db.syncQueue,
          )..where((t) => t.id.equals(item.id))).go();
          pushed++;
        } catch (error) {
          debugPrint('Fallo al sincronizar ${item.id}: $error');
          await _scheduleRetry(item);
        }
      }
      // RF-6 de la 007: tras un sync completado se recalcula la fatiga. Un
      // fallo aquí no debe tumbar el resto del ciclo.
      if (pushed > 0) {
        try {
          await onSyncCompleted?.call();
        } catch (error) {
          debugPrint('Fallo al recalcular la fatiga: $error');
        }
      }
    } finally {
      _isSyncing = false;
    }
    try {
      await onCycleCompleted?.call();
    } catch (error) {
      debugPrint('Fallo en la tarea de fin de ciclo: $error');
    }
  }

  Future<void> _scheduleRetry(SyncQueueData item) async {
    final attempts = item.attempts + 1;
    // RF-14: backoff exponencial 1 s, 2 s, 4 s… con techo de 60 s.
    final backoffSeconds = min(1 << (attempts - 1), 60);
    // RF-15: a partir de 11 fallos el item queda en dead_letter, sin borrarse.
    final isDeadLetter = attempts > 10;

    await (_db.update(_db.syncQueue)..where((t) => t.id.equals(item.id))).write(
      SyncQueueCompanion(
        attempts: Value(attempts),
        status: Value(isDeadLetter ? 'dead_letter' : item.status),
        nextAttemptAt: Value(
          DateTime.now().add(Duration(seconds: backoffSeconds)),
        ),
      ),
    );

    if (isDeadLetter) {
      _notices.add('No se pudo sincronizar un cambio de ${item.targetTable}.');
    }
  }

  Future<void> _pushToSupabase(
    String table,
    String operation,
    Map<String, dynamic> row,
  ) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw StateError('Supabase no está configurado');
    }

    if (operation == 'delete') {
      if (table == 'body_metrics') {
        await supabase
            .from(table)
            .delete()
            .eq('user_id', row['user_id'])
            .eq('date', row['date']);
      } else if (table == 'profiles') {
        await supabase.from(table).delete().eq('id', row['id']);
      } else {
        if (table == 'progress_photos' && row['path'] != null) {
          // RF-10: el objeto del bucket privado se elimina con la fila.
          try {
            await supabase.storage.from('progress-photos').remove([
              row['path'] as String,
            ]);
          } catch (error) {
            debugPrint('Fallo al borrar la foto de Storage: $error');
          }
        }
        await supabase.from(table).delete().eq('id', row['id']);
      }
      return;
    }

    if (table == 'body_metrics') {
      await supabase.from(table).upsert(row, onConflict: 'user_id,date');
      return;
    }

    if (table == 'profiles') {
      await supabase.from(table).upsert(row, onConflict: 'id');
      return;
    }

    await supabase.from(table).upsert(row, onConflict: 'id');
  }

  /// Encola una operación de mutación local para ser enviada a Supabase (RF-11)
  Future<void> enqueueMutation(
    String operation,
    String targetTable,
    String payloadJson,
  ) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: id,
            operation: operation,
            targetTable: targetTable,
            payload: payloadJson,
            nextAttemptAt: DateTime.now(), // Intento inmediato
          ),
        );
    processQueue();
  }
}
