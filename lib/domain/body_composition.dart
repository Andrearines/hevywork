import 'dart:math' as math;

import '../data/local/database.dart' show BodyMetric;
import 'body_metrics.dart' show decodeMeasures;

/// Composición corporal calculada de un registro (spec 009, RF-1/RF-3).
///
/// El % de grasa manual manda; si falta, se estima con la ecuación US Navy a
/// partir de las medidas del mismo registro. La masa magra manual manda; si
/// falta, se deriva de peso y grasa.
typedef BodyComposition = ({
  double? bodyFatPct,
  double? leanMassKg,
  bool estimatedBodyFat,
});

/// Clave del sexo en `local_profiles.sex`.
const String kSexMale = 'male';
const String kSexFemale = 'female';

/// Rango fisiológico válido del % de grasa (spec 009, validaciones).
const double kBodyFatMin = 0;
const double kBodyFatMax = 70;

/// Ecuación US Navy de % de grasa (spec 009, RF-4).
///
/// Hombres usan cuello, cintura y altura; mujeres añaden cadera al perímetro
/// (spec 006: la medida `hip` alimenta la ecuación femenina). Devuelve null
/// si faltan datos, si los perímetros son imposibles o si el resultado cae
/// fuera del rango fisiológico.
double? navyBodyFatPercent({
  required String? sex,
  required double? heightCm,
  required double? neckCm,
  required double? waistCm,
  double? hipCm,
}) {
  if (heightCm == null || heightCm <= 0) return null;
  if (neckCm == null || neckCm <= 0) return null;
  if (waistCm == null || waistCm <= 0) return null;

  final double value;
  if (sex == kSexFemale) {
    if (hipCm == null || hipCm <= 0) return null;
    final circumference = waistCm + hipCm - neckCm;
    if (circumference <= 0) return null;
    value = 495 /
            (1.29579 -
                0.35004 * _log10(circumference) +
                0.22100 * _log10(heightCm)) -
        450;
  } else if (sex == kSexMale) {
    final circumference = waistCm - neckCm;
    if (circumference <= 0) return null;
    value = 495 /
            (1.0324 -
                0.19077 * _log10(circumference) +
                0.15456 * _log10(heightCm)) -
        450;
  } else {
    return null;
  }

  if (!value.isFinite) return null;
  if (value < kBodyFatMin || value > kBodyFatMax) return null;
  return value;
}

/// Ecuación US Navy a partir del mapa de medidas de un registro.
double? navyBodyFatFromMeasures({
  required String? sex,
  required double? heightCm,
  required Map<String, double> measures,
}) =>
    navyBodyFatPercent(
      sex: sex,
      heightCm: heightCm,
      neckCm: measures['neck'],
      waistCm: measures['waist'],
      hipCm: measures['hip'],
    );

/// Masa magra derivada de peso y % de grasa (duda abierta de la spec 009:
/// `peso × (1 − %grasa/100)`). Null si falta alguno o el resultado no es
/// positivo.
double? leanMassKgFor({required double? weightKg, required double? bodyFatPct}) {
  if (weightKg == null || weightKg <= 0) return null;
  if (bodyFatPct == null) return null;
  final value = weightKg * (1 - bodyFatPct / 100);
  return value > 0 ? value : null;
}

/// Composición de un registro: manual si existe, estimada si no.
BodyComposition compositionOf(
  BodyMetric record, {
  String? sex,
  double? heightCm,
}) {
  final measures = decodeMeasures(record.measuresJson);
  final estimated =
      navyBodyFatFromMeasures(sex: sex, heightCm: heightCm, measures: measures);
  final manualFat = _validFat(record.bodyFatPct);
  final bodyFatPct = manualFat ?? estimated;
  final leanMassKg = record.leanMassKg ??
      leanMassKgFor(weightKg: record.weightKg, bodyFatPct: bodyFatPct);
  return (
    bodyFatPct: bodyFatPct,
    leanMassKg: leanMassKg,
    estimatedBodyFat: manualFat == null && estimated != null,
  );
}

/// Composición de todos los registros que aportan algún dato, de más antiguo
/// a más reciente (el delta compara con el anterior de esta lista).
List<BodyComposition> compositionHistory(
  List<BodyMetric> records, {
  String? sex,
  double? heightCm,
}) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  return [
    for (final record in sorted)
      if (_hasComposition(record, sex: sex, heightCm: heightCm))
        compositionOf(record, sex: sex, heightCm: heightCm),
  ];
}

/// Última composición disponible, o null si ningún registro aporta datos.
BodyComposition? latestComposition(
  List<BodyMetric> records, {
  String? sex,
  double? heightCm,
}) {
  final history =
      compositionHistory(records, sex: sex, heightCm: heightCm);
  return history.isEmpty ? null : history.last;
}

/// Composición inmediatamente anterior a la última, para el Δ del grid.
BodyComposition? previousComposition(
  List<BodyMetric> records, {
  String? sex,
  double? heightCm,
}) {
  final history =
      compositionHistory(records, sex: sex, heightCm: heightCm);
  return history.length < 2 ? null : history[history.length - 2];
}

/// Etiqueta en español del origen del % de grasa (solo presentación).
String bodyFatSourceLabel({required bool estimated}) =>
    estimated ? 'Estimado · US Navy' : 'Registro manual';

bool _hasComposition(
  BodyMetric record, {
  String? sex,
  double? heightCm,
}) {
  if (record.bodyFatPct != null || record.leanMassKg != null) return true;
  final composition = compositionOf(record, sex: sex, heightCm: heightCm);
  return composition.bodyFatPct != null || composition.leanMassKg != null;
}

double? _validFat(double? value) {
  if (value == null) return null;
  if (value < kBodyFatMin || value > kBodyFatMax) return null;
  return value;
}

double _log10(double value) => math.log(value) / math.ln10;
