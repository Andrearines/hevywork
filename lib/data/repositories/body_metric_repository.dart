import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/body_composition.dart';
import '../../domain/body_metrics.dart';
import '../local/database.dart';
import 'workout_repository.dart' show MutationEnqueuer;

/// Registro diario de peso y medidas corporales (spec 006, RF-1/RF-2): una
/// fila por `(usuario, día)` con upsert por fecha (el último del día gana),
/// edición y borrado de cualquier registro. Único punto de escritura de la
/// tabla; cada cambio se encola para sincronizar (RF-11). Desde la spec 009
/// (RF-1/RF-2) la fila guarda también composición corporal.
class BodyMetricRepository {
  final AppDatabase _db;
  final MutationEnqueuer? enqueue;

  BodyMetricRepository(this._db, {this.enqueue});

  Stream<List<BodyMetric>> watchRecords() => (_db.select(_db.bodyMetrics)
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();

  /// El día civil (medianoche local) que identifica un registro.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Crea o actualiza el registro del día (RF-2: el último del mismo día
  /// gana). Requiere al menos peso, medidas, composición o notas.
  Future<BodyMetric> upsert({
    required DateTime date,
    double? weightKg,
    double? bodyFatPct,
    double? leanMassKg,
    Map<String, double>? measures,
    String? notes,
  }) async {
    final day = dayOf(date);
    if (weightKg != null && weightKg <= 0) {
      throw ArgumentError.value(weightKg, 'weightKg');
    }
    if (bodyFatPct != null &&
        (bodyFatPct < kBodyFatMin || bodyFatPct > kBodyFatMax)) {
      throw ArgumentError.value(bodyFatPct, 'bodyFatPct');
    }
    if (leanMassKg != null && leanMassKg <= 0) {
      throw ArgumentError.value(leanMassKg, 'leanMassKg');
    }
    final trimmedNotes = notes?.trim() ?? '';
    final hasWeight = weightKg != null;
    final hasComposition = bodyFatPct != null || leanMassKg != null;
    final hasMeasures = measures != null && measures.isNotEmpty;
    if (!hasWeight && !hasComposition && !hasMeasures && trimmedNotes.isEmpty) {
      throw ArgumentError('El registro necesita peso, medidas o notas');
    }
    if (measures != null &&
        measures.keys.any((id) => !kBodyMeasures.contains(id))) {
      throw ArgumentError.value(measures, 'measures');
    }
    final now = DateTime.now();
    final profile = await _profile();
    final existing = await (_db.select(_db.bodyMetrics)
          ..where((t) =>
              t.localUserId.equals(profile.localUserId) & t.date.equals(day)))
        .getSingleOrNull();
    final createdAt = existing?.createdAt ?? now;
    final measuresJson = hasMeasures ? encodeMeasures(measures) : null;
    final cleanNotes = trimmedNotes.isEmpty ? null : trimmedNotes;

    await _db.into(_db.bodyMetrics).insertOnConflictUpdate(
          BodyMetricsCompanion(
            localUserId: Value(profile.localUserId),
            date: Value(day),
            weightKg: Value(weightKg),
            bodyFatPct: Value(bodyFatPct),
            leanMassKg: Value(leanMassKg),
            measuresJson: Value(measuresJson),
            notes: Value(cleanNotes),
            createdAt: Value(createdAt),
            updatedAt: Value(now),
          ),
        );
    await _enqueueRow(
      'upsert',
      'body_metrics',
      {
        'date': day.toIso8601String(),
        'weight_kg': ?weightKg,
        'body_fat_pct': ?bodyFatPct,
        'lean_mass_kg': ?leanMassKg,
        if (hasMeasures) 'measures_json': measures,
        'notes': ?cleanNotes,
      },
    );
    return BodyMetric(
      localUserId: profile.localUserId,
      date: day,
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      leanMassKg: leanMassKg,
      measuresJson: measuresJson,
      notes: cleanNotes,
      createdAt: createdAt,
      updatedAt: now,
    );
  }

  /// Borra el registro de un día cualquiera (RF-2).
  Future<void> delete(DateTime date) async {
    final day = dayOf(date);
    final profile = await _profile();
    await (_db.delete(_db.bodyMetrics)
          ..where((t) =>
              t.localUserId.equals(profile.localUserId) & t.date.equals(day)))
        .go();
    await _enqueueRow(
      'delete',
      'body_metrics',
      {'date': day.toIso8601String()},
    );
  }

  /// Último peso registrado, o null sin mediciones de peso.
  Future<double?> latestWeightKg() async {
    final row = await (_db.select(_db.bodyMetrics)
          ..where((t) => t.weightKg.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
    return row?.weightKg;
  }

  Future<LocalProfile> _profile() async =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _enqueueRow(
    String operation,
    String table,
    Map<String, dynamic> payload,
  ) async {
    await enqueue?.call(operation, table, jsonEncode(payload));
  }
}