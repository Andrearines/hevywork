import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/services/rest_notifier.dart';

void main() {
  late RestNotifier notifier;

  setUp(() {
    notifier = RestNotifier();
  });

  group('IDs por timer', () {
    test('legacy conserva 1 y los IDs de items son estables y distintos', () {
      expect(
        RestNotifier.notificationIdFor(RestNotificationService.legacyKey),
        1,
      );
      expect(RestNotifier.notificationIdFor('workout-exercise-a'), 1089720387);
      expect(RestNotifier.notificationIdFor('workout-exercise-b'), 1106498006);
      expect(
        RestNotifier.notificationIdFor('workout-exercise-a'),
        isNot(RestNotifier.notificationIdFor('workout-exercise-b')),
      );
    });
  });

  group('alertNow', () {
    test('no lanza excepción en llamadas múltiples', () async {
      // Primeira llamada
      await notifier.alertNow();
      // Segunda llamada (debe ser no-op gracias a la bandera interna)
      await notifier.alertNow();
      // Tercera llamada después de llamar a resetAlertFlag
      notifier.resetAlertFlag();
      await notifier.alertNow();
    });
  });

  group('resetAlertFlag', () {
    test('prepara el sistema para un nuevo aviso', () async {
      // Llamar alertNow varias veces para marcar la bandera
      await notifier.alertNow();
      await notifier.alertNow();
      // Resetear bandera
      notifier.resetAlertFlag();
      // El siguiente alertNow debería completar sin error (al aguardarlo)
      await notifier.alertNow();
    });
  });
}
