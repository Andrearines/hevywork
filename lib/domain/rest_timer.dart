/// Fase del temporizador de descanso (RF-5 a RF-8 de la 002).
enum RestTimerPhase { idle, running, paused, done }

/// Temporizador de descanso anclado a un instante absoluto (`DateTime`) para
/// que el tiempo restante sea correcto aunque la app vuelva del fondo o se
/// restaure la sesión (RF-10). No depende de timers: el resto se calcula
/// contra `DateTime.now()`.
class RestTimer {
  const RestTimer({
    this.endsAt,
    this.pausedRemaining,
  });

  /// Instante absoluto en el que termina el descanso; null si no corre.
  final DateTime? endsAt;

  /// Tiempo restante mientras está en pausa; null si no está en pausa.
  final Duration? pausedRemaining;

  RestTimerPhase phaseAt(DateTime now) {
    final paused = pausedRemaining;
    if (paused != null) return RestTimerPhase.paused;
    final ends = endsAt;
    if (ends == null) return RestTimerPhase.idle;
    return now.isBefore(ends) ? RestTimerPhase.running : RestTimerPhase.done;
  }

  Duration remainingAt(DateTime now) {
    final paused = pausedRemaining;
    if (paused != null) return paused;
    final ends = endsAt;
    if (ends == null) return Duration.zero;
    final rest = ends.difference(now);
    return rest.isNegative ? Duration.zero : rest;
  }

  /// Arranca un descanso de [duration] segundos a partir de [now].
  RestTimer start(DateTime now, Duration duration) => RestTimer(
        endsAt: now.add(duration),
      );

  RestTimer pause(DateTime now) {
    if (endsAt == null) return this;
    return RestTimer(pausedRemaining: remainingAt(now));
  }

  RestTimer resume(DateTime now) {
    final paused = pausedRemaining;
    if (paused == null) return this;
    return RestTimer(endsAt: now.add(paused));
  }

  /// Ajusta el tiempo restante (RF-8); nunca queda negativo.
  RestTimer adjust(Duration delta, DateTime now) {
    final remaining = remainingAt(now) + delta;
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    if (pausedRemaining != null) {
      return RestTimer(pausedRemaining: clamped);
    }
    if (endsAt == null) return RestTimer();
    return RestTimer(endsAt: now.add(clamped));
  }

  /// Salta el descanso (RF-8): vuelve al estado inactivo.
  RestTimer skip() => const RestTimer();

  /// `true` si acaba de llegar a cero (transición running -> done).
  bool justFinished(DateTime now) {
    final ends = endsAt;
    if (ends == null || pausedRemaining != null) return false;
    return !now.isBefore(ends);
  }
}