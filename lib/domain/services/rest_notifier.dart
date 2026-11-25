import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract class RestNotificationService {
  static const String legacyKey = 'legacy-workout';

  Future<void> scheduleAt(
    DateTime when, {
    String timerKey = legacyKey,
    String title = 'Descanso terminado',
    String body = 'Reanuda tu sesión',
  });

  Future<void> cancel({String timerKey = legacyKey});

  Future<void> alertNow({String timerKey = legacyKey});

  void resetAlertFlag({String timerKey = legacyKey});
}

/// Avisos del temporizador de descanso (RF-7 de la 002).
///
/// - En primer plano: sonido + vibración con el SDK de Flutter.
/// - En background: notificación local programada en el instante exacto
///   (`zonedSchedule`), aprobada en la spec 002 (§2 de la constitución).
///
/// Todos los fallos (plataforma sin soporte, permisos denegados) se tragan:
/// el descanso y la sesión nunca pueden romperse por un aviso.
class RestNotifier implements RestNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final Set<String> _alertDismissed = {};

  static const String _restTimerChannelId = 'rest_timer_v2';

  static int notificationIdFor(String timerKey) {
    if (timerKey == RestNotificationService.legacyKey) return 1;
    var hash = 0x811c9dc5;
    for (final codeUnit in timerKey.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final id = hash & 0x7fffffff;
    return id < 2 ? id + 2 : id;
  }

  RestNotifier() {
    // Los canales se crearán al hacer init en _ensureReady
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Reanudar'),
    );
    await _plugin.initialize(settings: initialization);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    _ready = true;
  }

  /// Programa la notificación local para el instante [when].
  @override
  Future<void> scheduleAt(
    DateTime when, {
    String timerKey = RestNotificationService.legacyKey,
    String title = 'Descanso terminado',
    String body = 'Reanuda tu sesión',
  }) async {
    try {
      await _ensureReady();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _restTimerChannelId,
          'Descanso',
          channelDescription: 'Aviso del temporizador de descanso',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );
      await _plugin.zonedSchedule(
        id: notificationIdFor(timerKey),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Sin soporte o sin permisos: el aviso en primer plano cubre el caso.
    }
  }

  /// Elimina la notificación programada pendiente.
  @override
  Future<void> cancel({
    String timerKey = RestNotificationService.legacyKey,
  }) async {
    try {
      await _plugin.cancel(id: notificationIdFor(timerKey));
    } catch (_) {}
  }

  /// Aviso en primer plano: sonido + vibración si el dispositivo lo soporta.
  /// Intenta usar SystemSound + vibración; si falla, intenta notificación local.
  @override
  Future<void> alertNow({
    String timerKey = RestNotificationService.legacyKey,
  }) async {
    // Evitar duplicados: solo un aviso por descanso
    if (_alertDismissed.contains(timerKey)) return;
    _alertDismissed.add(timerKey);

    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {
      // Fallback: notificación local si SystemSound no está disponible
      try {
        await _plugin.show(
          id: notificationIdFor(timerKey),
          title: 'Descanso terminado',
          body: 'Reanuda tu sesión',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _restTimerChannelId,
              'Descanso',
              channelDescription: 'Aviso del temporizador de descanso',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: false,
              presentSound: true,
            ),
          ),
        );
      } catch (_) {
        // Silenciar si nada funciona: el descanso y la sesión nunca rompen.
      }
    }
  }

  /// Restablece la bandera de aviso para un nuevo descanso.
  @override
  void resetAlertFlag({String timerKey = RestNotificationService.legacyKey}) {
    _alertDismissed.remove(timerKey);
  }
}
