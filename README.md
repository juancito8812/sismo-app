# SismoVE 🇻🇪

App Android de alertas sísmicas para Venezuela — monitoreo local 100% offline-first con datos de USGS y fuentes venezolanas.

## Características

- 📡 **Sismología en tiempo real** — consume el feed de USGS y filtra eventos cercanos a Venezuela
- 🔔 **Notificaciones push** — alerta automática para sismos M ≥ 3.0
- ⏰ **Polling en background** — cada 15 minutos via Workmanager
- 📋 **Lista de eventos** — colores por magnitud, badge de nuevos, pull-to-refresh
- 🗺️ **Mapa** — visualización geográfica de sismos (flutter_map)
- 🔍 **Filtros** — por magnitud, periodo y zona
- 📄 **Detalle** — profundidad, coordenadas, fuente del evento
- ⚙️ **Ajustes** — intervalo de polling, umbral mínimo
- 💾 **Exportar CSV** — historial completo de eventos
- 📦 **100% local** — SQLite offline-first, sin depender de servidores externos

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter 3.24.x |
| Lenguaje | Dart 3.x |
| Maps | flutter_map + OpenStreetMap |
| DB local | SQLite (sqflite) |
| Notificaciones | flutter_local_notifications |
| Background | workmanager |
| Geolocalización | geolocator |
| Permisos | permission_handler |
| Fuente sismológica | USGS Earthquake API + FUNVISIS / CIMA (próximamente) |

## Requisitos

- Flutter SDK 3.24.x
- Android SDK 34+
- JDK 17+

## Compilar

```bash
# Obtener dependencias
flutter pub get

# Generar platform files (si no existen)
flutter create --platforms android .

# Build APK release
flutter build apk --release

# El APK queda en:
# build/app/outputs/flutter-apk/app-release.apk
```

## Estructura del proyecto

```
lib/
├── main.dart                 # Entry point + Workmanager init
├── data/
│   ├── earthquake.dart       # Modelo Earthquake
│   ├── local_db.dart         # SQLite singleton
│   └── repository.dart       # Fuentes de datos (USGS)
├── screens/
│   └── home.dart             # Pantalla principal
└── services/
    ├── background_poller.dart   # Worker periódico en background
    └── notification_service.dart # Notificaciones locales
```

## Permisos Android

- `INTERNET` — consultar APIs sismológicas
- `POST_NOTIFICATIONS` — alertas de sismos
- `SCHEDULE_EXACT_ALARM` / `RECEIVE_BOOT_COMPLETED` — polling programado
- `VIBRATE` — vibración en notificaciones
- `WAKE_LOCK` / `FOREGROUND_SERVICE` — worker en background

## Roadmap

- [x] Scaffold base (modelo, DB, home)
- [x] Background polling + notificaciones
- [x] Badge de nuevos + pull-to-refresh
- [x] Icono personalizado + crash fix (MainActivity, try-catch Workmanager)
- [x] APK release compilado y funcional (commit `049b7d2`)
- [x] Mapa con marcadores por magnitud
- [x] Pantalla de detalle del evento
- [x] Filtros inline (magnitud, fecha, fuente) + ajustes
- [x] Exportar historial a CSV + limpiar DB
- [x] Scraping de FUNVISIS / CIMA
- [ ] Firma APK release + Google Play

## Licencia

MIT
