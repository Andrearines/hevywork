import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Avisos del temporizador de descanso (RF-7 de la 002).
///
/// - En primer plano: sonido + vibración con el SDK de Flutter.
/// - En background: notificación local programada en el instante exacto
///   (`zonedSchedule`), aprobada en la spec 002 (§2 de la constitución).
///
/// Todos los fallos (plataforma sin soporte, permisos denegados) se tragan:
/// el descanso y la sesión nunca pueden romperse por un aviso.
class RestNotifier {
  static const int _notificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _alertDismissed = false;

  static const String _restTimerChannelId = 'rest_timer_v2';

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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    _ready = true;
  }

  /// Programa la notificación local para el instante [when].
  Future<void> scheduleAt(
    DateTime when, {
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
        id: _notificationId,
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
  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }

  /// Aviso en primer plano: sonido + vibración si el dispositivo lo soporta.
  /// Intenta usar SystemSound + vibración; si falla, intenta notificación local.
  Future<void> alertNow() async {
    // Evitar duplicados: solo un aviso por descanso
    if (_alertDismissed) return;
    _alertDismissed = true;

    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {
      // Fallback: notificación local si SystemSound no está disponible
      try {
        await _plugin.show(
          id: _notificationId,
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
  void resetAlertFlag() {
    _alertDismissed = false;
  }
}