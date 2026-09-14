import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'sismos_channel';
  static const _channelName = 'Alertas de sismos';
  static const _channelDescription =
      'Notificaciones de sismos en Venezuela';

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(init);
  }

  /// Patrón de vibración de emergencia (aprox. SOS) en ms.
  static const _vibrationPattern = [
    0, 400, 200, 400, 200, 400, 800, 400, 800, 400, 800, 400,
  ];

  AndroidNotificationDetails _androidAlertDetails({String body = ''}) {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      vibrationPattern: Int64List.fromList(_vibrationPattern),
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('sos_beep'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: BigTextStyleInformation(body),
      ticker: body,
    );
  }

  /// Crea el canal Android por adelantado. Necesario cuando un push llega
  /// con la app terminada: la notificación local del handler de FCM debe
  /// encontrar el canal ya creado (con su sonido y vibración).
  Future<void> ensureChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('sos_beep'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(_vibrationPattern),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await android.createNotificationChannel(channel);
  }

  Future<void> showSismoAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = _androidAlertDetails(body: body);
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details);
  }
}
