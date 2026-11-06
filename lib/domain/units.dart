/// Unidades globales de presentación (specs 006 y 008, RF-29): kg y cm son
/// siempre la base de almacenamiento y cálculo; lb e in se usan solo al
/// presentar y editar.
library;

/// Kilogramos por libra (exacto por definición).
const double kKgPerLb = 2.2046226218;

/// Centímetros por pulgada.
const double kCmPerIn = 2.54;

/// Etiqueta de peso del sistema: 'kg' en métrico, 'lb' en imperial.
String weightUnitOf(String unitSystem) =>
    unitSystem == 'imperial' ? 'lb' : 'kg';

/// Etiqueta de longitud del sistema: 'cm' en métrico, 'in' en imperial.
String lengthUnitOf(String unitSystem) =>
    unitSystem == 'imperial' ? 'in' : 'cm';

/// Convierte un peso almacenado en kg a la unidad del sistema para
/// presentarlo.
double displayWeightKg(double kg, String unitSystem) =>
    unitSystem == 'imperial' ? kg * kKgPerLb : kg;

/// Convierte un peso presentado en la unidad del sistema a kg para
/// guardarlo.
double toKg(double value, String unitSystem) =>
    unitSystem == 'imperial' ? value / kKgPerLb : value;

/// Convierte una longitud almacenada en cm a la unidad del sistema para
/// presentarla.
double displayLengthCm(double cm, String unitSystem) =>
    unitSystem == 'imperial' ? cm / kCmPerIn : cm;

/// Convierte una longitud presentada en la unidad del sistema a cm para
/// guardarla.
double toCm(double value, String unitSystem) =>
    unitSystem == 'imperial' ? value * kCmPerIn : value;

/// Formatea un valor numérico para mostrar: entero sin decimales y el resto
/// con máximo dos decimales.
String formatDisplay(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(2);
}

/// Formatea un peso (base kg) en la unidad del sistema, sin etiqueta.
String formatWeightKg(double kg, String unitSystem) =>
    formatDisplay(displayWeightKg(kg, unitSystem));

/// Formatea una longitud (base cm) en la unidad del sistema, sin etiqueta.
String formatLengthCm(double cm, String unitSystem) =>
    formatDisplay(displayLengthCm(cm, unitSystem));

/// Paso de edición de peso: 1,25 kg en métrico y 2,5 lb en imperial.
double weightStepOf(String unitSystem) =>
    unitSystem == 'imperial' ? 2.5 : 1.25;

/// Paso de edición de longitud: 1 cm en métrico y 0,5 in en imperial.
double lengthStepOf(String unitSystem) =>
    unitSystem == 'imperial' ? 0.5 : 1;
