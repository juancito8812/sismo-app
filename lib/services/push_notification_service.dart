import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/earthquake.dart';
import '../data/local_db.dart';
import '../services/alert_engine.dart';
import '../services/notification_service.dart';

/// Tópico FCM al que se suscriben todos los dispositivos. El backend publica
/// cada sismo una sola vez al tópico (no a tokens individuales), y cada
/// cliente decide localmente si supera su umbral de alerta.
const kPushTopic = 'sismos_ve';

/// Clave de prefs con el último token FCM conocido (solo informativo/debug,
/// se muestra en Ajustes).
const kPushTokenKey = 'fcm_token';

/// Handler de nivel superior: FCM exige una función global (top-level) para
/// procesar mensajes cuando la app está en background o terminada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En el isolate de background Firebase debe inicializarse antes de usar
  // cualquier plugin de Firebase.
  await Firebase.initializeApp();
  await PushNotificationService.handlePushMessage(message);
}

/// Campos de un sismo recibido por push.
class PushQuakeData {
  const PushQuakeData({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
  });

  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double depthKm;

  Earthquake toEarthquake() => Earthquake(
        id: id,
        magnitude: magnitude,
        place: place,
        time: time,
        latitude: latitude,
        longitude: longitude,
        depthKm: depthKm,
        source: 'USGS',
      );
}

/// Parsea el payload `data` de un mensaje FCM en [PushQuakeData].
///
/// Devuelve null si el mensaje no es una alerta de sismo válida (data
/// faltante o campos no numéricos). Función pura: testeable sin plugins.
PushQuakeData? parseQuakeData(
  Map<String, String?> data, {
  DateTime? receivedAt,
}) {
  final id = (data['id'] ?? '').trim();
  final mag = double.tryParse((data['mag'] ?? '').trim());
  if (id.isEmpty || mag == null) return null;

  final timeRaw = int.tryParse((data['time'] ?? '').trim());
  final time = timeRaw != null
      ? DateTime.fromMillisecondsSinceEpoch(timeRaw)
      : (receivedAt ?? DateTime.now());

  return PushQuakeData(
    id: id,
    magnitude: mag,
    place: (data['place'] ?? '').trim(),
    time: time,
    latitude: double.tryParse((data['lat'] ?? '').trim()) ?? 0,
    longitude: double.tryParse((data['lon'] ?? '').trim()) ?? 0,
    depthKm: double.tryParse((data['depth'] ?? '').trim()) ?? 0,
  );
}

/// Decisión pura de notificación push: toggle de alertas + umbral local.
/// Espeja el gate de [_deliver]; testeable sin plugins.
bool shouldNotifyPush({
  required double mag,
  required double minMag,
  required bool enabled,
}) {
  return enabled && mag >= minMag;
}

/// Alertas push vía Firebase Cloud Messaging.
///
/// Estrategia: el backend (Cloud Functions) consulta USGS cada 5 minutos y
/// publica un mensaje *data-only* al tópico. El cliente recibe, aplica su
/// umbral local y muestra la notificación con el mismo canal/sonido que el
/// polling — así el push y el polling comparten pipeline y deduplicación.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  /// Payload del sismo cuya notificación abrió la app (foreground tap o
  /// cold start). Null si el arranque no vino de una notificación; Home lo
  /// consume y lo limpia con [clearInitialNotificationPayload].
  PushQuakeData? _initialPayload;

  /// Datos del sismo cuya notificación abrió la app, o null si el arranque
  /// no vino de un tap en una notificación.
  PushQuakeData? get initialNotificationPayload => _initialPayload;

  /// Limpia el payload inicial, ya consumido por Home.
  void clearInitialNotificationPayload() => _initialPayload = null;

  /// Ids siendo procesados en este isolate (evita doble notificación si FCM
  /// entrega el mismo mensaje dos veces en ráfaga).
  static final Set<String> _inFlight = <String>{};

  /// Callback de UI al abrir la app desde una notificación (lo registra
  /// HomeScreen). Estático porque onMessageOpenedApp también es estático.
  static Future<void> Function()? _onTap;

  /// Registra el callback invocado cuando la app se abre desde una
  /// notificación push.
  static set onTapNotification(Future<void> Function()? cb) => _onTap = cb;

  static void _notifyTap() {
    final cb = _onTap;
    if (cb != null) unawaited(cb());
  }

  /// Inicializa Firebase + FCM en foreground: permisos, suscripción al
  /// tópico, token y listener de mensajes.
  ///
  /// Todos los pasos son tolerantes a fallos: si Firebase no está
  /// configurado (p. ej. google-services.json placeholder), la app funciona
  /// igual con el polling del AlertEngine.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp(); // lee google-services.json en Android
    } catch (e) {
      // ignore: avoid_print
      print('[push] Firebase no disponible (se usará solo polling): $e');
      _initialized = false;
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Canal Android creado desde ya: si un push llega con la app cerrada,
    // la notificación local necesita el canal existente con su sonido.
    try {
      await NotificationService.instance.init();
      await NotificationService.instance.ensureChannels();
    } catch (_) {}

    // Permiso de notificaciones (Android 13+ usa POST_NOTIFICATIONS del
    // manifest; el diálogo lo dispara esta llamada).
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    // Un solo tópico para todos: el backend publica una vez y todos los
    // dispositivos la reciben; el filtro por umbral es local.
    try {
      await messaging.subscribeToTopic(kPushTopic);
    } catch (_) {}

    // Foreground: los mensajes data-only no se muestran solos — la
    // convertimos en notificación local (mismo canal que el polling).
    FirebaseMessaging.onMessage.listen(
      (message) => unawaited(handlePushMessage(message)),
    );

    // Tap en notificación con la app en background: guarda el payload y
    // avisa a la UI para abrir el detalle del sismo.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _storePayloadFrom(message);
      _notifyTap();
    });

    // Cold start: la app fue abierta tocando una notificación cuando
    // estaba terminada. getInitialMessage() solo lo expone aquí.
    unawaited(_captureInitialMessage(messaging));

    unawaited(_saveToken(messaging));
    messaging.onTokenRefresh.listen(
      (_) => unawaited(_saveToken(messaging)),
    );
  }

  /// Guarda el payload de un mensaje como payload inicial si es una alerta
  /// de sismo válida.
  void _storePayloadFrom(RemoteMessage message) {
    final quake = parseQuakeData(
      message.data.map((k, v) => MapEntry(k, v?.toString())),
      receivedAt: DateTime.now(),
    );
    if (quake != null) _initialPayload = quake;
  }

  Future<void> _captureInitialMessage(FirebaseMessaging messaging) async {
    try {
      final message = await messaging.getInitialMessage();
      if (message == null) return;
      _storePayloadFrom(message);
      _notifyTap();
    } catch (_) {}
  }

  Future<void> _saveToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kPushTokenKey, token);
      }
    } catch (_) {
      // El token es informativo; si falla no afecta la recepción.
    }
  }

  /// Procesa un mensaje FCM (foreground o background): parsea, aplica
  /// umbral/toggle y muestra la notificación local. Idempotente con el
  /// polling: un evento nunca suena dos veces.
  static Future<void> handlePushMessage(RemoteMessage message) async {
    try {
      final data = <String, String?>{
        for (final entry in message.data.entries)
          entry.key: entry.value?.toString(),
      };
      final quake = parseQuakeData(data, receivedAt: DateTime.now());
      if (quake == null) return; // no es una alerta de sismo
      await _deliver(quake);
    } catch (e) {
      // ignore: avoid_print
      print('[push] error procesando mensaje: $e');
    }
  }

  static Future<void> _deliver(PushQuakeData q) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kAlertsEnabledKey) ?? true;
    final minMag =
        prefs.getDouble(kAlertMinMagnitudeKey) ?? kDefaultAlertMinMagnitude;

    final eq = q.toEarthquake();

    // Anti-spam: ignora eventos que llegan tarde (reintentos, cola FCM).
    if (DateTime.now().difference(eq.time) > kFreshnessWindow) return;

    final db = LocalDb.instance;
    final existing = await db.byId(eq.id);

    // Ya sonó antes: ¿USGS lo revisó al alza de forma significativa?
    if (existing != null && existing.notified == 1) {
      final rev = enabled
          ? decideRevision(
              previous: existing,
              updated: eq,
              minMagnitude: minMag,
            )
          : null;
      if (rev == null) {
        // Sin re-alerta: mantené el historial al día con la versión revisada.
        if (existing.magnitude != eq.magnitude) {
          await db.upsertNotified(eq);
        }
        return;
      }
      if (!_inFlight.add(eq.id)) return;
      await _showAndMark(eq, rev.titleFor(eq), rev.bodyFor(eq, minMag));
      return;
    }

    // Primera notificación del evento.
    if (!shouldNotifyPush(
      mag: eq.magnitude,
      minMag: minMag,
      enabled: enabled,
    )) {
      // Debajo del umbral (o toggle apagado): solo sincroniza el historial.
      await db.upsertNotified(eq);
      return;
    }
    if (!_inFlight.add(eq.id)) return;
    await _showAndMark(
      eq,
      'Sismo detectado M${eq.magnitude.toStringAsFixed(1)}',
      eq.place,
    );
  }

  /// Persiste, muestra la notificación local y marca como notificado.
  /// El llamador debe haber agregado el id a [_inFlight] antes de llamar.
  static Future<void> _showAndMark(
    Earthquake eq,
    String title,
    String body,
  ) async {
    final db = LocalDb.instance;
    try {
      await db.upsertNotified(eq);
      await NotificationService.instance.init();
      await NotificationService.instance.ensureChannels();
      await NotificationService.instance.showSismoAlert(
        id: eq.id.hashCode & 0x7FFFFFFF,
        title: title,
        body: body,
      );
      await db.markNotified(eq.id);
    } finally {
      _inFlight.remove(eq.id);
    }
  }
}
