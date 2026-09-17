import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handler de tap en background (app terminada). El plugin exige una función
/// top-level; el procesamiento real del tap lo hace el isolate principal vía
/// [NotificationService.onQuakeTap] o `getNotificationAppLaunchDetails()`.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

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

  /// Payload (id del sismo) de una notificación tocada mientras la UI aún no
  /// registraba su router. [PushNotificationService] lo drena al inicializar.
  static String? pendingTapPayload;

  /// Router invocado cuando el usuario toca una notificación local con
  /// payload. Lo asigna [PushNotificationService.initialize] al arrancar.
  static void Function(String quakeId)? onQuakeTap;

  /// Procesa el tap de una notificación local con payload. Público para
  /// poder testear el ruteo sin plugins; [init] lo conecta al plugin.
  static void handleTapResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final router = onQuakeTap;
    if (router != null) {
      router(payload);
    } else {
      // UI aún no lista: dejar en espera para consumir después.
      pendingTapPayload ??= payload;
    }
  }

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: handleTapResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    // Cold start: la app fue lanzada tocando una notificación local. Se
    // captura acá (antes de que la UI exista) y Home la consume al iniciar.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        pendingTapPayload ??= payload;
      }
    } catch (_) {}
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
    String? payload,
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
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
