import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();

  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isPlaying = false;

  // Listas de callbacks para soportar múltiples listeners
  final List<VoidCallback> _onStartListeners = [];
  final List<VoidCallback> _onCompleteListeners = [];
  final List<VoidCallback> _onStopListeners = [];
  final List<void Function(String word, int start, int end)> _onProgressListeners = [];

  factory TTSService() {
    return _instance;
  }

  TTSService._internal() {
    _flutterTts = FlutterTts();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      // Crear copia para evitar modificación durante iteración
      final listeners = List<VoidCallback>.from(_onStartListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onStart: $e');
        }
      }
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      final listeners = List<VoidCallback>.from(_onCompleteListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onComplete: $e');
        }
      }
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      final listeners = List<VoidCallback>.from(_onStopListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onStop: $e');
        }
      }
    });

    _flutterTts.setPauseHandler(() {
      _isPlaying = false;
      final listeners = List<VoidCallback>.from(_onStopListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onPause: $e');
        }
      }
    });

    _flutterTts.setContinueHandler(() {
      _isPlaying = true;
      final listeners = List<VoidCallback>.from(_onStartListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onContinue: $e');
        }
      }
    });

    _flutterTts.setProgressHandler((
      String text,
      int start,
      int end,
      String word,
    ) {
      final listeners = List<void Function(String, int, int)>.from(_onProgressListeners);
      for (var listener in listeners) {
        try {
          listener(word, start, end);
        } catch (e) {
          debugPrint('Error en listener onProgress: $e');
        }
      }
    });
  }

  void addOnStartListener(VoidCallback callback) {
    _onStartListeners.add(callback);
  }

  void addOnCompleteListener(VoidCallback callback) {
    _onCompleteListeners.add(callback);
  }

  void addOnStopListener(VoidCallback callback) {
    _onStopListeners.add(callback);
  }

  void addOnProgressListener(void Function(String word, int start, int end) callback) {
    _onProgressListeners.add(callback);
  }

  void removeOnStartListener(VoidCallback callback) {
    _onStartListeners.remove(callback);
  }

  void removeOnCompleteListener(VoidCallback callback) {
    _onCompleteListeners.remove(callback);
  }

  void removeOnStopListener(VoidCallback callback) {
    _onStopListeners.remove(callback);
  }

  void removeOnProgressListener(void Function(String word, int start, int end) callback) {
    _onProgressListeners.remove(callback);
  }

  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('es-ES');
      _isInitialized = true;
      debugPrint('✅ TTS Service inicializado');
    } catch (e) {
      debugPrint('❌ Error initializing TTS: $e');
    }
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (text.isEmpty) return;
    
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Set language if provided
      if (languageCode != null) {
        await _flutterTts.setLanguage(languageCode);
      }

      // Stop any ongoing speech first
      if (_isPlaying) {
        await _flutterTts.stop();
        // Esperar a que se complete el stop
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Speak the text
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ Error speaking text: $e');
      _isPlaying = false;
      final listeners = List<VoidCallback>.from(_onStopListeners);
      for (var listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error en listener onError: $e');
        }
      }
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      // Esperamos un poco para asegurar que el handler se ejecute
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      print('Error stopping speech: $e');
      _isPlaying = false;
      for (var listener in _onStopListeners) {
        listener();
      }
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      // No establecemos _isPlaying ni llamamos onStop aquí,
      // lo hará el setPauseHandler
    } catch (e) {
      print('Error pausing speech: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _flutterTts.speak("");
      // No establecemos _isPlaying aquí,
      // lo hará el setContinueHandler
    } catch (e) {
      print('Error resuming speech: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      print('Error setting speech rate: $e');
    }
  }

  String getLanguageCode(String langId) {
    switch (langId) {
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'ca':
        return 'ca-ES';
      case 'pt':
        return 'pt-PT';
      case 'fr':
        return 'fr-FR';
      case 'it':
        return 'it-IT';
      case 'de':
        return 'de-DE';
      default:
        return 'es-ES';
    }
  }
}
