import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Activa Firebase App Check en el cliente.
///
/// Provider según build:
/// - **Debug** (`kDebugMode`): `debugProvider` — no requiere Play Integrity,
///   y el token de debug sale en el log para registrarlo en la consola.
/// - **Release**: `playIntegrityProvider` (Play Integrity API, Android).
///
/// La activación es tolerante a fallos y best-effort: si falla (Firebase no
/// configurado, Play Services ausente en el dispositivo, etc.), la app
/// funciona igual — App Check no guarda estado y puede reintentarse.
///
/// ⚠ Debe llamarse **antes** de cualquier llamada a Cloud Functions: el
/// cliente adjunta el token de App Check automáticamente a cada callable.
///
/// Con App Check *enforced* en el backend, las llamables rechazan requests
/// sin token válido (`unauthenticated`); con modo *monitor*, solo se
/// registran en métricas (ver PUSH_SETUP.md → App Check).
class AppCheckService {
  AppCheckService._();
  static final AppCheckService instance = AppCheckService._();

  bool _activated = false;

  Future<void> activate() async {
    if (_activated) return;
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
      _activated = true;
    } catch (_) {
      // Best-effort: sin App Check el resto de la app funciona igual.
    }
  }
}
