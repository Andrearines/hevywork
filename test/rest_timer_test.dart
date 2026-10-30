import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/rest_timer.dart';

void main() {
  final base = DateTime(2026, 10, 7, 18, 0, 0);

  group('RestTimer (RF-5 a RF-8 de la 002)', () {
    test('arranca y cuenta el tiempo restante contra ahora', () {
      final timer = const RestTimer().start(base, const Duration(seconds: 90));

      expect(timer.phaseAt(base), RestTimerPhase.running);
      expect(timer.remainingAt(base), const Duration(seconds: 90));
      expect(
        timer.remainingAt(base.add(const Duration(seconds: 30))),
        const Duration(seconds: 60),
      );
      expect(
        timer.remainingAt(base.add(const Duration(milliseconds: 90500))),
        const Duration(seconds: 0),
      );
      expect(
        timer.phaseAt(base.add(const Duration(seconds: 91))),
        RestTimerPhase.done,
      );
    });

    test('pausa congela el resto y reanudar lo descuenta desde ahí', () {
      final timer = const RestTimer()
          .start(base, const Duration(seconds: 90))
          .pause(base.add(const Duration(seconds: 40)));

      expect(timer.phaseAt(base.add(const Duration(seconds: 40))),
          RestTimerPhase.paused);
      expect(
        timer.remainingAt(base.add(const Duration(seconds: 400))),
        const Duration(seconds: 50),
      );

      final resumed =
          timer.resume(base.add(const Duration(hours: 2)));
      expect(resumed.phaseAt(base.add(const Duration(hours: 2))),
          RestTimerPhase.running);
      expect(
        resumed.remainingAt(base.add(const Duration(hours: 2, seconds: 20))),
        const Duration(seconds: 30),
      );
    });

    test('ajustar el resto lo acorta o lo alarga sin pasar a negativo', () {
      final timer = const RestTimer()
          .start(base, const Duration(seconds: 90))
          .adjust(const Duration(seconds: 15), base);

      expect(
        timer.remainingAt(base),
        const Duration(seconds: 105),
      );

      final negative = timer.adjust(const Duration(seconds: -200), base);
      expect(negative.remainingAt(base), Duration.zero);
      expect(negative.phaseAt(base), RestTimerPhase.done);
    });

    test('ajustar o reanudar respeta que esté en pausa', () {
      final paused = const RestTimer()
          .start(base, const Duration(seconds: 90))
          .pause(base.add(const Duration(seconds: 50)))
          .adjust(const Duration(seconds: 15), base);

      expect(paused.phaseAt(base), RestTimerPhase.paused);
      expect(paused.remainingAt(base), const Duration(seconds: 55));

      final idle = paused.skip();
      expect(idle.phaseAt(base), RestTimerPhase.idle);
      expect(idle.remainingAt(base), Duration.zero);
    });

    test('justFinished solo es true en la transición de llegada a cero', () {
      final timer = const RestTimer().start(base, const Duration(seconds: 5));
      expect(timer.justFinished(base), isFalse);
      expect(timer.justFinished(base.add(const Duration(seconds: 5))), isTrue);

      final paused = timer.pause(base.add(const Duration(seconds: 3)));
      expect(paused.justFinished(base.add(const Duration(seconds: 99))),
          isFalse);

      expect(const RestTimer().justFinished(base), isFalse);
    });
  });
}