# SismoVE 🇻🇪

App Android de alertas sísmicas para Venezuela — monitoreo local 100% offline-first con datos de USGS y preparación sísmica integral.

![Build](https://github.com/juancito8812/sismo-app/actions/workflows/build-apk.yml/badge.svg)
[![Latest Release](https://img.shields.io/github/v/release/juancito8812/sismo-app)](https://github.com/juancito8812/sismo-app/releases/latest)

## Características

### 📡 Monitoreo sísmico
- **Sismología en tiempo real** — consume el feed USGS filtrado para Venezuela
- **Notificaciones push** — alerta automática para sismos M ≥ 3.0
- **Polling en background** — cada 15 minutos via Workmanager
- **Lista de eventos** — colores por magnitud, badge de nuevos, pull-to-refresh
- **Mapa** — visualización geográfica con marcadores por magnitud (flutter_map)
- **Detalle del evento** — profundidad, coordenadas, fuente, mapa embedido
- **Filtros inline** — por magnitud mínima, período (24h/7d/30d) y fuente
- **Seed histórico** — descarga 42+ eventos desde enero 2026 para pruebas

### 🧰 Preparación sísmica
| Feature | Descripción |
|---------|-------------|
| **Guía de seguridad** | ANTES/DURANTE/DESPUÉS — qué hacer en cada fase |
| **Kit de emergencia** | Checklist interactivo de 20 ítems con progreso guardado |
| **Contactos VE** | 8 números de emergencia: Protección Civil, Bomberos, Cruz Roja, etc. |
| **Linterna SOS** | Pantalla blanca brillo máximo + parpadeo morse ··· −−− ··· |
| **Plan familiar** | Punto de encuentro + contactos + notas + botón "Estoy bien" |
| **Reportar sismo** | Formulario: ¿lo sentiste?, ubicación, intensidad (1-5), daños |
| **Primeros auxilios** | Guía offline: RCP, hemorragias, fracturas, Heimlich |
| **Zonas de riesgo** | Mapa con 7 zonas sísmicas de Venezuela + leyenda de peligro |

### 🔄 Auto-actualización
- **Update checker integrado** — consulta la última release de GitHub
- **Descarga directa** — botón para descargar el APK más reciente
- **CI/CD automático** — cada push genera release con APK

### ⚙️ Datos
- **Exportar CSV** — historial completo a documentos del dispositivo
- **Limpiar DB** — eliminar todos los eventos registrados
- **100% local** — SQLite offline-first, sin servidores externos

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter 3.27.x |
| Lenguaje | Dart 3.x |
| Maps | flutter_map + OpenStreetMap |
| DB local | SQLite (sqflite) |
| Notificaciones | flutter_local_notifications |
| Background | workmanager |
| Persistencia | shared_preferences |
| Llamadas | url_launcher |
| Export | csv + path_provider |
| Fuente sismológica | USGS Earthquake API + FUNVISIS scraping |

## Requisitos

- Flutter SDK 3.27.x
- Android SDK 34+
- JDK 17+

## Descargar

[![Latest Release](https://img.shields.io/github/v/release/juancito8812/sismo-app)](https://github.com/juancito8812/sismo-app/releases/latest)

Descarga el APK más reciente desde [GitHub Releases](https://github.com/juancito8812/sismo-app/releases/latest).

> ⚠️ Al ser una release fuera de Google Play, Android puede pedirte activar "Instalar apps de orígenes desconocidos". Aceptalo para instalar.

## Compilar

```bash
# Obtener dependencias
flutter pub get

# Build APK release (sin ProGuard para evitar conflictos R8)
flutter build apk --release --no-shrink

# El APK queda en:
# build/app/outputs/flutter-apk/app-release.apk
```

## Estructura del proyecto

```
lib/
├── main.dart                           # Entry point + Workmanager
├── data/
│   ├── earthquake.dart                 # Modelo + color helper
│   ├── local_db.dart                   # SQLite singleton + migración
│   └── repository.dart                 # USGS API + scraping + seed
├── screens/
│   ├── home.dart                       # Pantalla principal + navegación
│   ├── event_detail.dart               # Detalle del evento + mini-mapa
│   ├── map_screen.dart                 # Mapa global con marcadores
│   ├── settings_screen.dart            # Filtros, seed, export, limpiar
│   ├── safety_guide.dart               # Guía ANTES/DURANTE/DESPUÉS
│   ├── emergency_kit.dart              # Checklist kit de emergencia
│   ├── emergency_contacts.dart         # Contactos VE para llamar
│   ├── torch_sos.dart                  # Linterna + SOS morse
│   ├── family_plan.dart                # Plan familiar + "Estoy bien"
│   ├── felt_report.dart                # Reportar sismo sentido
│   ├── first_aid.dart                  # Primeros auxilios offline
│   └── risk_zones.dart                 # Mapa de zonas de riesgo
└── services/
    ├── background_poller.dart          # Worker periódico en background
    └── notification_service.dart       # Notificaciones locales
```

## Permisos Android

- `INTERNET` — consultar APIs sismológicas
- `POST_NOTIFICATIONS` — alertas de sismos
- `SCHEDULE_EXACT_ALARM` / `RECEIVE_BOOT_COMPLETED` — polling programado
- `VIBRATE` — vibración en notificaciones
- `WAKE_LOCK` / `FOREGROUND_SERVICE` — worker en background

## Roadmap

- [x] Scaffold base + modelo + DB + home
- [x] Background polling + notificaciones push
- [x] Mapa con marcadores + detalle del evento
- [x] Filtros inline + ajustes + export CSV
- [x] Seed histórico USGS + scraping FUNVISIS
- [x] Guía de seguridad + kit emergencia + contactos VE
- [x] Linterna SOS + plan familiar + reportar sismo
- [x] Primeros auxilios + zonas de riesgo
- [x] Auto-update checker desde GitHub Releases
- [x] CI/CD: GitHub Actions build + release automático
- [ ] Firma APK + Google Play

## Licencia

MIT
