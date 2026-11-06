import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/services/rest_notifier.dart';

void main() {
  late RestNotifier notifier;

  setUp(() {
    notifier = RestNotifier();
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