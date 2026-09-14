import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../data/earthquake.dart';
import '../data/local_db.dart';
import '../data/repository.dart';
import '../services/background_poller.dart';
import '../services/notification_service.dart';

/// Claves de preferencias de alertas (compartidas con Settings).
const kAlertMinMagnitudeKey = 'alert_min_magnitude';
const kAlertsEnabledKey = 'alerts_enabled';

/// Umbral por defecto para disparar notificación.
const double kDefaultAlertMinMagnitude = 3.0;

/// Configuración del polling en background vía WorkManager.
class AlertEnginePolling {
  AlertEnginePolling._();

  /// Inicializa WorkManager y registra la tarea periódica.
  ///
  /// [force] re-registra la tarea aunque ya exista (usado al cambiar el
  /// intervalo en Ajustes). Por defecto usa [ExistingWorkPolicy.keep] para
  /// no resetear el schedule en cada arranque de la app.
  static Future<void> configure({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final pollMinutes = prefs.getInt('poll_interval') ?? 15;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      'sismos.background',
      kBackgroundChannel,
      frequency: Duration(minutes: pollMinutes),
      existingWorkPolicy: force ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}

/// Ventana de frescura: solo se notifican eventos ocurridos dentro de este
/// lapso. Evita ruido del seed histórico o de eventos viejos que aparezcan
/// por primera vez en el feed (público: el push la comparte para descartar
/// mensajes re-entregados tarde).
const kFreshnessWindow = Duration(hours: 6);

/// Lógica pura de decisión de alertas: dado el feed sincronizado, el set de
/// eventos pendientes (no notificados y frescos), el umbral y el toggle,
/// devuelve los ids que deben disparar notificación. Testeable sin red/DB.
List<String> alertDecisions({
  required List<Earthquake> events,
  required Set<String> pendingIds,
  required double minMagnitude,
  required bool enabled,
}) {
  final out = <String>[];
  for (final eq in events) {
    if (eq.magnitude < minMagnitude) continue;
    if (enabled && pendingIds.contains(eq.id)) out.add(eq.id);
  }
  return out;
}

/// Cambio de magnitud tan chico que no se considera revisión.
const double kRevisionEpsilon = 0.05;

/// Escalamiento (en magnitud) que justifica re-alertar un evento ya notificado.
const double kEscalationDelta = 0.5;

/// Tipos de revisión que justifican re-alertar un evento ya notificado.
enum QuakeRevisionKind {
  /// Estaba debajo del umbral del usuario y la revisión lo cruzó hacia arriba.
  crossedThreshold,

  /// Se intensificó [kEscalationDelta] o más manteniéndose sobre el umbral.
  escalated,
}

/// Revisión significativa de un evento ya notificado.
class QuakeRevision {
  const QuakeRevision({required this.kind, required this.previousMagnitude});

  final QuakeRevisionKind kind;
  final double previousMagnitude;

  String titleFor(Earthquake updated) =>
      'Sismo revisado: M${updated.magnitude.toStringAsFixed(1)} '
      '(era M${previousMagnitude.toStringAsFixed(1)})';

  String bodyFor(Earthquake updated, double minMagnitude) {
    final motivo = kind == QuakeRevisionKind.crossedThreshold
        ? 'Superó tu umbral de M${minMagnitude.toStringAsFixed(1)}'
        : 'Se intensificó +${(updated.magnitude - previousMagnitude).toStringAsFixed(1)}';
    return '${updated.place} · $motivo';
  }
}

/// Decide si un evento ya conocido fue revisado por USGS de forma que amerite
/// re-alertar: cruzó el umbral hacia arriba o escaló [kEscalationDelta]+.
/// Las revisiones triviales o a la baja devuelven null (solo actualizan el
/// historial). Testeable sin red/DB.
QuakeRevision? decideRevision({
  required Earthquake? previous,
  required Earthquake updated,
  required double minMagnitude,
}) {
  if (previous == null) return null;
  final delta = updated.magnitude - previous.magnitude;
  if (delta.abs() < kRevisionEpsilon) return null;
  // Solo eventos aún frescos re-alertan; los históricos solo actualizan
  // el historial.
  if (DateTime.now().difference(updated.time) > kFreshnessWindow) return null;
  // Si nunca sonó, no es re-alerta: lo maneja alertDecisions como primera
  // notificación.
  if (previous.notified != 1) return null;

  final crossed =
      previous.magnitude < minMagnitude && updated.magnitude >= minMagnitude;
  final escalated =
      delta >= kEscalationDelta && updated.magnitude >= minMagnitude;
  if (crossed) {
    return QuakeRevision(
      kind: QuakeRevisionKind.crossedThreshold,
      previousMagnitude: previous.magnitude,
    );
  }
  if (escalated) {
    return QuakeRevision(
      kind: QuakeRevisionKind.escalated,
      previousMagnitude: previous.magnitude,
    );
  }
  return null;
}

/// Resultado de un sync: el feed actual y el estado previo en DB de esos
/// mismos ids (para detectar revisiones de USGS).
class _SyncResult {
  const _SyncResult({required this.events, required this.previous});
  final List<Earthquake> events;
  final Map<String, Earthquake> previous;
}

class AlertEngine {
  AlertEngine._();
  static final AlertEngine instance = AlertEngine._();

  Timer? _liveTimer;
  bool _running = false;

  /// Monitoreo en vivo mientras la app está abierta: corre el chequeo cada
  /// 2 minutos (mucho más rápido que el poller de background).
  Future<void> startLiveMonitoring() async {
    if (_liveTimer != null) return;
    // Primer chequeo inmediato, luego periódico.
    unawaited(_safeRunCheck());
    _liveTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_safeRunCheck()),
    );
  }

  void stopLiveMonitoring() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  Future<void> _safeRunCheck() async {
    if (_running) return; // evita solapamiento de ciclos
    _running = true;
    try {
      await runCheck();
    } catch (_) {
      // el monitoreo vivo no debe tumbar la app si falla la red
    } finally {
      _running = false;
    }
  }

  /// Corre un ciclo de chequeo: trae eventos de USGS, persiste los nuevos y
  /// notifica los que superen el umbral guardado (si las alertas están
  /// activas). Idempotente: un evento nunca se notifica dos veces.
  ///
  /// Devuelve la cantidad de notificaciones emitidas en este ciclo.
  Future<int> runCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kAlertsEnabledKey) ?? true;
    final minMag =
        prefs.getDouble(kAlertMinMagnitudeKey) ?? kDefaultAlertMinMagnitude;

    final notifier = NotificationService.instance;
    await notifier.init();

    var notified = 0;
    // El sync captura el estado previo de cada evento ANTES de pisarlo con
    // el feed: así se detectan revisiones de USGS.
    final sync = await _syncEvents();
    final events = sync.events;

    // "Pendiente" = no notificado + suficientemente fresco. Se calcula
    // DESPUÉS del sync para incluir eventos que acaban de llegar.
    final pendingIds = await LocalDb.instance.pendingAlertIds(
      maxAge: kFreshnessWindow,
    );
    final toNotify = alertDecisions(
      events: events,
      pendingIds: pendingIds,
      minMagnitude: minMag,
      enabled: enabled,
    );
    // Re-alertas: eventos ya notificados cuya magnitud fue revisada al alza
    // de forma significativa (cruce de umbral o escalación).
    final revisions = <String, QuakeRevision>{};
    if (enabled) {
      for (final eq in events) {
        final rev = decideRevision(
          previous: sync.previous[eq.id],
          updated: eq,
          minMagnitude: minMag,
        );
        if (rev != null) revisions[eq.id] = rev;
      }
    }
    for (final eq in events) {
      final qualifies = eq.magnitude >= minMag;
      final rev = revisions[eq.id];
      if (!qualifies && rev == null) continue;
      if (rev != null) {
        await notifier.showSismoAlert(
          id: eq.id.hashCode & 0x7FFFFFFF,
          title: rev.titleFor(eq),
          body: rev.bodyFor(eq, minMag),
        );
        notified++;
      } else if (toNotify.contains(eq.id)) {
        await notifier.showSismoAlert(
          id: eq.id.hashCode & 0x7FFFFFFF,
          title: 'Sismo detectado M${eq.magnitude.toStringAsFixed(1)}',
          body: eq.place,
        );
        notified++;
      }
      // Marcar como procesado siempre que califique, haya sonado o no,
      // para que un evento no reaparezca como "nuevo" en cada ciclo.
      await LocalDb.instance.markNotified(eq.id);
    }
    return notified;
  }

  /// Trae el feed reciente, captura el estado previo de esos eventos y lo
  /// persiste preservando el flag de notificación. Devuelve el feed ordenado
  /// por tiempo desc junto con el estado previo (para detectar revisiones).
  Future<_SyncResult> _syncEvents() async {
    final events = await EarthquakeRepository().fetchRecent();
    final previous = await LocalDb.instance
        .byIds(events.map((e) => e.id));
    for (final eq in events) {
      await LocalDb.instance.upsertNotified(eq);
    }
    await LocalDb.instance.pruneOldEvents();
    return _SyncResult(events: events, previous: previous);
  }

  /// Sincroniza el feed reciente con la DB, sin emitir notificaciones
  /// (usado por pull-to-refresh en la pantalla principal).
  Future<void> syncEvents() => _syncEvents();
}
