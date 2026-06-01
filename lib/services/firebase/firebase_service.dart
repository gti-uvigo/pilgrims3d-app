import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/env.dart';

/// Servicio centralizado para inicializar Firebase
class FirebaseService {
  static FirebaseApp? _app;
  static bool _initialized = false;

  /// Inicializa Firebase según la plataforma
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔥 Firebase ya está inicializado');
      return;
    }

    try {
      if (kIsWeb) {
        _app = await Firebase.initializeApp(
          options: const FirebaseOptions(
        apiKey: firebaseApiKey,
        authDomain: firebaseAuthDomain,
        projectId: firebaseProjectId,
        storageBucket: firebaseStorageBucket,
        messagingSenderId: firebaseMessagingSenderId,
        appId: firebaseAppId,
        measurementId: firebaseMeasurementId,
      ),
        );
      } else {
        _app = await Firebase.initializeApp();
      }

      _initialized = true;
      debugPrint('✅ Firebase inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando Firebase: $e');
      rethrow;
    }
  }

  /// Obtiene la instancia de Firebase
  static FirebaseApp get app {
    if (!_initialized || _app == null) {
      throw Exception('Firebase no ha sido inicializado. Llama a FirebaseService.initialize() primero.');
    }
    return _app!;
  }

  /// Verifica si Firebase está inicializado
  static bool get isInitialized => _initialized;

  /// Reinicia Firebase (útil para testing)
  static Future<void> reset() async {
    if (_initialized) {
      await _app?.delete();
      _app = null;
      _initialized = false;
      debugPrint('🔄 Firebase reiniciado');
    }
  }
}