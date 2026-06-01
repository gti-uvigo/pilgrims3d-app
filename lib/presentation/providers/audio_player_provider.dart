import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/audio.dart';
import '../../services/api/api_service.dart' as api;

/// Provider global para manejar el reproductor de audio flotante
class AudioPlayerProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioModel? _currentAudio;
  bool _isPlaying = false;
  bool _isLoading = false;

  AudioPlayer get audioPlayer => _audioPlayer;
  AudioModel? get currentAudio => _currentAudio;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasAudio => _currentAudio != null;

  AudioPlayerProvider() {
    _setupListeners();
    
    // Configurar el AudioPlayer para Android e iOS
    _audioPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
      ),
    );
    
    // Configurar modo de reproducción en segundo plano
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      notifyListeners();
    });
  }

  String _extensionFromContentType(String contentType) {
    final normalized = contentType.toLowerCase();
    if (normalized.contains('mpeg') || normalized.contains('mp3')) return 'mp3';
    if (normalized.contains('wav')) return 'wav';
    if (normalized.contains('aac')) return 'aac';
    if (normalized.contains('mp4') || normalized.contains('m4a')) return 'm4a';
    if (normalized.contains('ogg')) return 'ogg';
    return 'mp3';
  }

  Future<File> _writeAudioTempFile({
    required List<int> bytes,
    required String audioId,
    required String extension,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'audio_${audioId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Reproduce un nuevo audio
  Future<void> playAudio(AudioModel audio) async {
    try {
      _isLoading = true;
      _currentAudio = audio;
      notifyListeners();

      // Si ya hay un audio reproduciéndose, detenerlo
      await _audioPlayer.stop();

      final audioUrl = api.getAudioUrl(audio.metadata.audioId);
      print('🎵 Descargando audio desde: $audioUrl');

      // Descargar el audio con timeout
      final response = await http.get(
        Uri.parse(audioUrl),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Timeout después de 30 segundos');
          throw Exception('Timeout al descargar el audio después de 30 segundos');
        },
      );

      print('📦 Status Code: ${response.statusCode}');
      print('📦 Content-Type: ${response.headers['content-type']}');
      print('📏 Content-Length: ${response.contentLength ?? response.bodyBytes.length} bytes');

      if (response.statusCode != 200) {
        throw Exception('Error al descargar el audio: ${response.statusCode}');
      }

      // Verificar que haya datos
      if (response.bodyBytes.isEmpty) {
        throw Exception('La respuesta del servidor está vacía');
      }

      // Verificar que no sea HTML SOLO si el archivo es pequeño
      final contentType = response.headers['content-type'] ?? '';
      final bodySize = response.bodyBytes.length;

      if (contentType.contains('text/html') && bodySize < 100000) {
        throw Exception('El servidor devolvió una página HTML en lugar de audio');
      } else if (contentType.contains('text/html')) {
        print('⚠️ Content-Type incorrecto (text/html) pero archivo grande ($bodySize bytes)');
        print('⚠️ Asumiendo que es audio y continuando...');
      }

      // En iOS AVPlayer es estricto con el tipo de archivo; reproducimos desde
      // un fichero temporal con extensión válida para evitar setSourceUrl failed.
      final extension = _extensionFromContentType(contentType);
      final tempFile = await _writeAudioTempFile(
        bytes: response.bodyBytes,
        audioId: audio.metadata.audioId,
        extension: extension,
      );

      print('🎼 Reproduciendo audio desde archivo temporal: ${tempFile.path}');
      await _audioPlayer.play(
        DeviceFileSource(
          tempFile.path,
          mimeType: contentType.isNotEmpty ? contentType : null,
        ),
      );

      print('✅ Audio cargado y reproduciendo');
    } catch (e) {
      print('❌ Error al reproducir audio: $e');
      _currentAudio = null;
      _isPlaying = false;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pausa el audio actual
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Reanuda el audio actual
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  /// Detiene el audio y cierra el reproductor
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentAudio = null;
    _isPlaying = false;
    notifyListeners();
  }

  /// Verifica si un audio específico está reproduciéndose
  bool isAudioPlaying(String audioId) {
    return _currentAudio?.metadata.audioId == audioId && _isPlaying;
  }

  /// Verifica si un audio específico es el actual (aunque esté pausado)
  bool isCurrentAudio(String audioId) {
    return _currentAudio?.metadata.audioId == audioId;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
