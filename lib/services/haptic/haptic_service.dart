import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Servicio centralizado para gestionar feedback háptico y vibraciones
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;
  bool _isInitialized = false;

  /// Inicializa el servicio y verifica las capacidades del dispositivo
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
  _hasVibrator = await Vibration.hasVibrator();
  _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      _isInitialized = true;
    } catch (e) {
      print('Error al inicializar HapticService: $e');
      _hasVibrator = false;
      _hasAmplitudeControl = false;
    }
  }

  /// Feedback ligero para interacciones pequeñas (toques en botones)
  Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Feedback medio para interacciones normales (selecciones, cambios)
  Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Feedback pesado para acciones importantes (confirmaciones, alertas)
  Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Feedback para selecciones (switches, checkboxes)
  Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibración de éxito (para confirmaciones exitosas)
  Future<void> success() async {
    if (!_hasVibrator) {
      await heavy();
      return;
    }
    
    try {
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 100, amplitude: 128);
      } else {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      await heavy();
    }
  }

  /// Vibración de error (para acciones fallidas o validaciones)
  Future<void> error() async {
    if (!_hasVibrator) {
      await heavy();
      return;
    }

    try {
      // Patrón de vibración: [espera, vibra, espera, vibra, espera, vibra]
      await Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 100]);
    } catch (e) {
      await heavy();
    }
  }

  /// Vibración de advertencia (para alertas importantes)
  Future<void> warning() async {
    if (!_hasVibrator) {
      await heavy();
      return;
    }

    try {
      // Patrón de vibración más largo
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 200, amplitude: 200);
      } else {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      await heavy();
    }
  }

  /// Vibración de notificación (para mensajes importantes)
  Future<void> notification() async {
    if (!_hasVibrator) {
      await medium();
      return;
    }

    try {
      // Patrón: [espera, vibra, espera, vibra]
      await Vibration.vibrate(pattern: [0, 50, 100, 50]);
    } catch (e) {
      await medium();
    }
  }

  /// Vibración personalizada con duración específica
  Future<void> custom({int duration = 100, int amplitude = 128}) async {
    if (!_hasVibrator) {
      await medium();
      return;
    }

    try {
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: duration, amplitude: amplitude);
      } else {
        await Vibration.vibrate(duration: duration);
      }
    } catch (e) {
      await medium();
    }
  }

  /// Vibración de navegación (al cambiar de página o sección)
  Future<void> navigation() async {
    await light();
  }

  /// Vibración para long press (mantener presionado)
  Future<void> longPress() async {
    await heavy();
  }

  /// Cancela todas las vibraciones en curso
  Future<void> cancel() async {
    if (_hasVibrator) {
      try {
        await Vibration.cancel();
      } catch (e) {
        print('Error al cancelar vibración: $e');
      }
    }
  }
}
