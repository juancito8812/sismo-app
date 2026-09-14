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
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
 * Envía el mensaje FCM de un sismo al tópico. Con [previousMag] no nulo lo
 * marca como revisión (campo `revisedFrom`).
 */
async function publishQuake(q, previousMag) {
  const isRevision = previousMag !== null && previousMag !== undefined;
  const message = {
    topic: TOPIC,
    data: {
      id: q.id,
      mag: String(q.mag),
      place: q.place,
      time: String(q.time),
      lat: String(q.lat),
      lon: String(q.lon),
      depth: String(q.depth),
    },
    android: { priority: "HIGH", ttl: 3600000 },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "background",
        "apns-collapse-id": q.id,
      },
    },
  };
  if (isRevision) {
    message.data.revisedFrom = String(previousMag);
  }
  await getMessaging().send(message);
  return isRevision;
}

/**
 * Pipeline completo de UN evento: validación, dedupe transaccional en
 * Firestore, envío FCM y rollback ante error. Es el mismo camino que usa
 * `sendTestQuake`, para que la prueba ejerza el pipeline real.
 *
 * f: feature GeoJSON de USGS (id, properties.mag/place/time, coordinates).
 */
async function processQuakeFeature(f, now) {
  const props = f.properties || {};
  const coords = (f.geometry && f.geometry.coordinates) || [];
  const mag = typeof props.mag === "number" ? props.mag : null;
  const time = typeof props.time === "number" ? props.time : null;
  if (!f.id || mag === null || time === null) return { skipped: "invalid" };
  // Aire de seguridad: un sismo viejo que recién aparece no suena.
  if (now - time > MAX_AGE_MS) return { skipped: "stale" };

  const db = getFirestore();
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
  if (!decision.publish) return { skipped: "duplicate" };

  try {
    const revision = await publishQuake(
      {
        id: f.id,
        mag,
        place: props.place || "",
        time,
        lat: coords.length > 1 ? coords[1] : 0,
        lon: coords.length > 0 ? coords[0] : 0,
        depth: coords.length > 2 ? coords[2] : 0,
      },
      decision.previousMag
    );
    return { id: f.id, mag, revision };
  } catch (err) {
    logger.error("fcm send failed", { id: f.id, error: String(err) });
    // Liberar la marca para que el próximo ciclo reintente. En revisión,
    // restaurar la magnitud previa para no perder el historial.
    if (decision.previousMag !== null && decision.previousMag !== undefined) {
      await dedupeRef
        .set(
          { mag: decision.previousMag, pushedAt: restorePushedAt(decision) },
          { merge: true }
        )
        .catch(() => {});
    } else {
      await dedupeRef.delete().catch(() => {});
    }
    return { skipped: "fcm_error" };
  }
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

  const sent = [];
  for (const f of features) {
    const out = await processQuakeFeature(f, now);
    if (out.id) {
      sent.push(out);
      logger.info(out.revision ? "pushed revision" : "pushed", {
        id: out.id,
        mag: out.mag,
      });
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

/**
 * Publica un sismo de PRUEBA al tópico para verificar el pipeline completo
 * (dedupe en Firestore → FCM → notificación local en el dispositivo) sin
 * esperar un temblor real.
 *
 * data:
 *   - revision: true  → primero publica M 4.0 y en la misma llamada publica
 *     la revisión M 4.6: ejercita el camino de re-alerta (escalación ≥ +0.5)
 *     y el campo `revisedFrom` (default).
 *   - revision: false → publica un sismo nuevo M 4.8 (camino de primera
 *     alerta).
 *   - mag: número opcional para el modo no-revisión (2.5–9.0).
 *   - secret: opcional; si definís la config `test.secret` (o la variable de
 *     entorno TEST_SECRET al desplegar), las llamadas sin el secreto correcto
 *     se rechazan. Vacío = función abierta (solo para pruebas iniciales).
 *
 * Los sismos de prueba usan ids `test-...` y quedarán en el historial del
 * dispositivo; limpialos con Ajustes → Limpiar DB.
 */
exports.sendTestQuake = onCall(async (request) => {
  const secret = process.env.TEST_SECRET || "";
  if (secret && request.data?.secret !== secret) {
    throw new HttpsError("permission-denied", "secret inválido");
  }

  const now = Date.now();
  const place = "⚠ PRUEBA — no es un sismo real";

  if (request.data?.revision === false) {
    const mag = Number(request.data?.mag ?? 4.8);
    if (!Number.isFinite(mag) || mag < 2.5 || mag > 9.0) {
      throw new HttpsError("invalid-argument", "mag debe estar entre 2.5 y 9.0");
    }
    const out = await processQuakeFeature(
      {
        id: `test-${now}`,
        properties: { mag, place, time: now },
        geometry: { coordinates: [-66.9, 10.5, 10] },
      },
      now
    );
    return { ok: true, mode: "new", result: out };
  }

  // Modo revisión (default): primera alerta M 4.0 + revisión M 4.6.
  const first = await processQuakeFeature(
    {
      id: `test-${now}`,
      properties: { mag: 4.0, place, time: now },
      geometry: { coordinates: [-66.9, 10.5, 10] },
    },
    now
  );
  // Pausa breve entre envíos: en un temblor real la revisión llega minutos
  // después; sin pausa, el cliente puede descartar el segundo mensaje como
  // duplicado concurrente mientras procesa el primero.
  await new Promise((resolve) => setTimeout(resolve, 2000));
  const revision = await processQuakeFeature(
    {
      id: `test-${now}`,
      properties: { mag: 4.6, place, time: now },
      geometry: { coordinates: [-66.9, 10.5, 10] },
    },
    now
  );
  return { ok: true, mode: "revision", first, revision };
});
