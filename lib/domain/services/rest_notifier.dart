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
          'rest_timer',
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
  Future<void> alertNow() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}