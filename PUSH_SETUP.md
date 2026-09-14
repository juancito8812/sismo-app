# Push instantáneo con Firebase Cloud Messaging (FCM)

El polling en background tiene un piso duro de **15 minutos** impuesto por
Android. Con FCM, la latencia media baja a **~2.5 minutos**: el backend
consulta USGS cada 5 minutos y publica por push al instante.

## Arquitectura

```
USGS ──> Cloud Function (scheduler cada 5 min) ──> tópico FCM "sismos_ve"
                                                        │
                                            mensaje data-only (id, mag,
                                            place, time, lat, lon, depth)
                                                        │
                                          ┌─────────────┴─────────────┐
                                          ▼                           ▼
                                   app en foreground          app en background/terminada
                                   (onMessage → handler)      (background isolate → handler)
                                          └─────────────┬─────────────┘
                                                        ▼
                                        filtro local por umbral + dedupe
                                        (misma DB y canal que el polling)
                                                        ▼
                                            notificación local
```

- **Un solo tópico** para todos los dispositivos: el backend publica una vez;
  el filtro por umbral es local (cambiar el umbral no toca el backend ni
  re-suscribe nada).
- **Dedupe doble**: Firestore (`pushedQuakes`) evita publicar dos veces el
  mismo evento; la DB local (`notified`) evita que push y polling lo
  notifiquen dos veces.
- **Revisiones de USGS**: la magnitud de un sismo suele revisarse en los
  minutos siguientes. Si un evento ya publicado sube **≥ +0.5** (y sigue
  sobre M 2.5), el backend lo re-publica con `revisedFrom` y el historial se
  actualiza; revisiones menores o a la baja solo actualizan datos, sin
  molestar al usuario. En el cliente vale la misma regla contra el umbral
  local: cruza tu umbral hacia arriba o escala ≥ +0.5 → re-alerta con el
  texto "Sismo revisado: M4.6 (era M4.0)".
- **Degradación elegante**: si Firebase no está configurado (o falla), la app
  sigue funcionando con el polling del AlertEngine.

## Paso 1 — Proyecto Firebase

1. Creá un proyecto en [console.firebase.google.com](https://console.firebase.google.com).
2. Agregá una app **Android** con el package exacto:
   `com.juancito8812.sismo_ve`
3. Descargá `google-services.json` y reemplazá el placeholder:
   `android/app/google-services.json`
4. En **Build → Firestore Database**, creá la base (modo producción está
   bien; solo el backend escribe ahí).
5. (Opcional, iOS) Agregá la app iOS con su bundle id y descargá
   `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`,
   luego habilitá capabilities *Push Notifications* y *Background Modes →
   Remote notifications*.

## Paso 2 — Backend

```bash
npm install -g firebase-tools   # una sola vez
firebase login
firebase use --add              # elegí tu proyecto
cd functions && npm install && cd ..
firebase deploy --only functions
```

Esto publica:

- `pollUsgsAndPush` — scheduler cada 5 min: consulta USGS (bbox de
  Venezuela, M ≥ 2.5), dedupe en Firestore y push al tópico.
- `ping` — callable de prueba para validar el deploy.
- `sendTestQuake` — publica un sismo de prueba para verificar el pipeline
  completo (dedupe → FCM → notificación) sin esperar un temblor real.

## Paso 3 — Verificar

1. `flutter pub get && flutter run` — aceptá el permiso de notificaciones.
2. En Ajustes → Alertas debería decir **"Alertas instantáneas activas"**.
3. Consola Firebase → Firestore: ante un sismo nuevo debe aparecer el doc en
   `pushedQuakes`.
4. Logs de la función: `firebase functions:log` — buscá `pushed`.

### Probar el pipeline completo (sendTestQuake)

Sin esperar un sismo real, dispará una prueba end-to-end:

```bash
PROJECT_ID=$(firebase use 2>/dev/null | head -1 | sed 's/^[A-Za-z]* //')
curl -s -X POST \
  "https://us-central1-${PROJECT_ID}.cloudfunctions.net/sendTestQuake" \
  -H "Content-Type: application/json" \
  -d '{"data": {}}'
```

En el dispositivo (con la app abierta o cerrada) deben llegar **dos
notificaciones**: `Sismo detectado M4.0` y luego `Sismo revisado: M4.6 (era
M4.0)` — la segunda ejercita el camino de revisión con el campo
`revisedFrom`. La respuesta del curl muestra el resultado de cada paso
(`first` y `revision`); si algún paso devuelve `skipped`, el motivo está en
el campo (`duplicate`, `stale`, `fcm_error`).

Variantes:

- Solo primera alerta (sin revisión): `'{"data": {"revision": false}}'`
- Con otra magnitud: `'{"data": {"revision": false, "mag": 3.2}}'`

Los sismos de prueba usan ids `test-...` y quedan en el historial local;
borralos con **Ajustes → Limpiar DB**. Para bloquear la función a terceros,
creá `functions/.env` con `TEST_SECRET=tu-secreto`, redeployá y pasá
`"secret": "..."` en el body (además del header de autenticación que la
API callable exige con llamadas no anónimas).

## Costos

En el plan **Spark (gratis)**: scheduler 5 min (~8.6k ejecuciones/mes) y
publicación por tópico caben en la cuota gratuita. Uso mínimo de Firestore
(1 doc por sismo). Si el proyecto escala, el plan Blaze se paga por uso y
sigue siendo despreciable para este volumen.

## Notas técnicas

- El mensaje es **data-only** con `android.priority: HIGH`: llega al
  background isolate aun con la app terminada; el handler crea la
  notificación local con el canal/sonido de alerta ya existentes.
- El canal de notificaciones se crea al arrancar la app (`ensureChannels`),
  necesario para que el push con app cerrada tenga sonido/vibración.
- `ttl: 1h`: un sismo viejo no despierta al usuario horas después.
- El fetch de USGS usa `orderby=time-asc` y una ventana de 10 min para no
  perder eventos entre ciclos.
- `sendTestQuake` reusa exactamente el mismo pipeline que el scheduler
  (validación → dedupe transaccional → FCM → rollback), así que la prueba
  no tiene atajos: si suena la prueba, suena el temblor real.
