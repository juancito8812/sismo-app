/**
 * SismoVE — backend de push con FCM.
 *
 * Publica cada sismo UNA vez al tópico `sismos_ve` como mensaje data-only.
 * El filtro por umbral es local a cada dispositivo (lee sus preferencias):
 * así cambiar el umbral no implica re-suscripciones ni lógica de backend.
 *
 * Despliegue: ver PUSH_SETUP.md
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

initializeApp();
// Régimen de costos por invocación (default). Región cerca de USGS/Caracas.
setGlobalOptions({ region: "us-central1", maxInstances: 2 });

const TOPIC = "sismos_ve";
// Debe coincidir con kVenezuelaMinLat/MaxLat/MinLon/MaxLon de earthquake.dart.
const BBOX = { minLat: -5, maxLat: 15, minLon: -75, maxLon: -60 };
// Debe coincidir con minmagnitude del EarthquakeRepository (lib/data/repository.dart).
const MIN_MAGNITUDE = 2.5;
// Frecuencia del scheduler: FCM requiere >= 1 minuto. 5 min => latencia
// media ~2.5 min desde el evento a la notificación (vs 15+ min del polling).
const SCHEDULE_EVERY = "every 5 minutes";
const POLL_URL = "https://earthquake.usgs.gov/fdsnws/event/1/query";
// Los sismos se procesan ~1-5 min después de ocurridos; ventana de seguridad.
const FETCH_WINDOW_MIN = 10;
// Descartar sismos muy viejos (reintentos del scheduler, colas, etc.).
const MAX_AGE_MS = 6 * 60 * 60 * 1000;
// Cambio de magnitud menor a esto no se considera revisión.
const REVISION_EPSILON = 0.05;
// Re-publicar push solo si USGS revisó la magnitud al alza en este delta o más.
const ESCALATION_DELTA = 0.5;

/** pushedAt de respaldo para el rollback de una revisión fallida. */
function restorePushedAt(decision) {
  return typeof decision.previousPushedAt === "number"
    ? decision.previousPushedAt
    : Date.now();
}

/**
 * Scheduler cada 5 min: consulta el feed USGS filtrado a Venezuela, dedup
 * contra Firestore y publica los nuevos al tópico FCM.
 */
exports.pollUsgsAndPush = onSchedule(SCHEDULE_EVERY, async (event) => {
  const now = Date.now();
  const since = new Date(now - FETCH_WINDOW_MIN * 60 * 1000).toISOString();
  const url =
    `${POLL_URL}?format=geojson&starttime=${since}` +
    `&minlatitude=${BBOX.minLat}&maxlatitude=${BBOX.maxLat}` +
    `&minlongitude=${BBOX.minLon}&maxlongitude=${BBOX.maxLon}` +
    `&minmagnitude=${MIN_MAGNITUDE}&orderby=time-asc`;

  let features;
  try {
    const resp = await fetch(url);
    if (!resp.ok) {
      logger.error("USGS HTTP error", { status: resp.status });
      return null;
    }
    const data = await resp.json();
    features = data.features || [];
  } catch (err) {
    logger.error("USGS fetch failed", { error: String(err) });
    return null;
  }

  const db = getFirestore();
  const sent = [];
  for (const f of features) {
    const props = f.properties || {};
    const coords = (f.geometry && f.geometry.coordinates) || [];
    const mag = typeof props.mag === "number" ? props.mag : null;
    const time = typeof props.time === "number" ? props.time : null;
    if (!f.id || mag === null || time === null) continue;
    // Aire de seguridad: un sismo viejo que recién aparece no suena.
    if (now - time > MAX_AGE_MS) continue;

    const dedupeRef = db.collection("pushedQuakes").doc(f.id);
    const decision = await db.runTransaction(async (tx) => {
      const doc = await tx.get(dedupeRef);
      if (!doc.exists) {
        tx.set(dedupeRef, { mag, time, pushedAt: now, revision: false });
        return { publish: true, previousMag: null };
      }
      // Ya publicado: ¿USGS revisó la magnitud al alza de forma significativa?
      const prev = doc.get("mag");
      const prevPushedAt = doc.get("pushedAt") || 0;
      if (
        typeof prev === "number" &&
        mag - prev >= ESCALATION_DELTA &&
        mag >= MIN_MAGNITUDE &&
        now - prevPushedAt <= MAX_AGE_MS
      ) {
        tx.set(
          dedupeRef,
          { mag, time, pushedAt: now, revision: true },
          { merge: true }
        );
        return {
          publish: true,
          previousMag: prev,
          previousPushedAt: prevPushedAt,
        };
      }
      // Revisión menor o a la baja: solo actualiza el historial, sin push.
      if (typeof prev === "number" && Math.abs(mag - prev) >= REVISION_EPSILON) {
        tx.set(dedupeRef, { mag, time }, { merge: true });
      }
      return { publish: false, previousMag: prev ?? null };
    });
    if (!decision.publish) continue;

    const isRevision = decision.previousMag !== null;
    const message = {
      topic: TOPIC,
      data: {
        id: f.id,
        mag: String(mag),
        place: props.place || "",
        time: String(time),
        lat: String(coords.length > 1 ? coords[1] : 0),
        lon: String(coords.length > 0 ? coords[0] : 0),
        depth: String(coords.length > 2 ? coords[2] : 0),
      },
      android: { priority: "HIGH", ttl: 3600000 },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "background",
          "apns-collapse-id": f.id,
        },
      },
    };
    if (isRevision) {
      message.data.revisedFrom = String(decision.previousMag);
    }

    try {
      await getMessaging().send(message);
      sent.push({ id: f.id, mag, revision: isRevision });
      logger.info(isRevision ? "pushed revision" : "pushed", {
        id: f.id,
        mag,
        previousMag: decision.previousMag,
      });
    } catch (err) {
      logger.error("fcm send failed", { id: f.id, error: String(err) });
      // Liberar la marca para que el próximo ciclo reintente. En revisión,
      // restaurar la magnitud previa para no perder el historial.
      if (isRevision) {
        await dedupeRef
          .set(
            { mag: decision.previousMag, pushedAt: restorePushedAt(decision) },
            { merge: true }
          )
          .catch(() => {});
      } else {
        await dedupeRef.delete().catch(() => {});
      }
    }
  }

  logger.info("cycle done", { total: features.length, pushed: sent.length });
  return { pushed: sent.length };
});

/**
 * RPC llamada desde la app para validar la configuración del backend
 * (disponible también en los emuladores).
 */
exports.ping = onCall(async () => {
  return { ok: true, topic: TOPIC };
});
