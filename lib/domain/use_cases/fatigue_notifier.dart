import 'dart:async';

/// Observer/Notifier de fatiga (spec 014, RF-4 y RF-10): escucha fuentes de
/// eventos —en producción los `tableUpdates` de drift de `workout_sets` y
/// `workouts`— y programa un único recálculo del caché `muscle_fatigue` con
/// debounce. Una ráfaga de N eventos se coalesce en un solo recálculo cada
/// [delay].
///
/// Patrón Observer/Notifier en Dart puro (sin Flutter ni dependencias):
/// `sources` y `recalculate` se inyectan en el constructor, así que el
/// dominio se prueba sin base de datos. La UI no se suscribe a este objeto:
/// se entera por los streams de drift (`watchFatigue`, `tableUpdates`).
class FatigueNotifier {
  /// Debounce por defecto de producción: coalesce las ráfagas de series y
  /// mantiene la actualización por debajo del umbral perceptible (RNF-2).
  static const Duration defaultDelay = Duration(milliseconds: 750);

  /// Ventana de debounce efectiva (corto en tests).
  final Duration delay;

  final Future<void> Function() _recalc;
  final List<StreamSubscription<void>> _subscriptions = [];
  final List<Stream<void>> _eventSources;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _dirty = false;
  bool _disposed = false;

  /// Crea el notifier y se suscribe a [sources] de inmediato. Cada emisión
  /// reinicia el temporizador de [delay] (debounce); los eventos que lleguen
  /// mientras un recálculo está en vuelo quedan marcados como sucios y se
  /// ejecutan después, sin duplicar vuelos concurrentes.
  FatigueNotifier({
    required List<Stream<void>> sources,
    required Future<void> Function() recalculate,
    this.delay = defaultDelay,
  })  : _eventSources = sources,
        _recalc = recalculate {
    for (final source in _eventSources) {
      _subscriptions.add(source.listen((_) => markDirty()));
    }
  }

  /// Marca la caché como sucia y (re)agenda el recálculo con debounce: cada
  /// evento reinicia el temporizador, de modo que una ráfaga de N eventos
  /// produce un solo recálculo tras [delay].
  void markDirty() {
    if (_disposed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, _onTimer);
  }

  /// Ejecuta el recálculo ya mismo y cancela el pendiente. Si ya hay un
  /// recálculo en vuelo, espera a que termine sin duplicarlo; si durante el
  /// vuelo llegaron más eventos, los ejecuta después. Tras `await flush()`
  /// la caché refleja los datos leídos; un error del recálculo se propaga
  /// a quien hace el await.
  Future<void> flush() async {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    // Ejecuta aunque no haya eventos marcados: el cierre de sesión y el
    // sync no dependen de la entrega asíncrona del evento de tabla.
    await _run();
    while (!_disposed && (_inFlight != null || _dirty)) {
      if (_inFlight != null) {
        await _inFlight;
      } else {
        await _run();
      }
    }
  }

  /// Cancela el temporizador y las suscripciones: tras llamar, ningún evento
  /// futuro dispara recálculos (sin fugas en los tests).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Espera breve a que termine el recálculo en vuelo antes de cancelar todo.
    if (_inFlight != null) {
      await _inFlight!.timeout(const Duration(seconds: 1));
    }
    _timer?.cancel();
    _timer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _dirty = false;
  }

  void _onTimer() {
    _timer = null;
    if (_disposed || !_dirty) return;
    // El camino del temporizador no tiene await: ignora el error para que un
    // fallo puntual del recálculo no se vuelva una excepción sin manejar.
    _run().ignore();
  }

  /// Ejecuta el recálculo o devuelve el que ya está en vuelo (deduplicación).
  /// Al ejecutar cancela el temporizador pendiente: la ejecución ya cubre lo
  /// marcado.
  Future<void> _run() {
    final existing = _inFlight;
    if (existing != null) return existing;
    _timer?.cancel();
    _timer = null;
    _dirty = false;
    final flight = _execute();
    _inFlight = flight;
    return flight;
  }

  Future<void> _execute() async {
    if (_disposed) return;
    try {
      await _recalc();
    } finally {
      _inFlight = null;
      // Eventos llegados durante el vuelo: se reagendan con el mismo debounce.
      if (_dirty && !_disposed) {
        _timer?.cancel();
        _timer = Timer(delay, _onTimer);
      }
    }
  }
}
