/// Modelo de datos para un audio de ruta
class AudioModel {
  final String id;
  final String filename;
  final int chunkSize;
  final int length;
  final AudioMetadata metadata;
  final DateTime uploadDate;

  AudioModel({
    required this.id,
    required this.filename,
    required this.chunkSize,
    required this.length,
    required this.metadata,
    required this.uploadDate,
  });

  /// Crea un AudioModel desde un JSON
  factory AudioModel.fromJson(Map<String, dynamic> json) {
    return AudioModel(
      id: json['_id'] as String,
      filename: json['filename'] as String,
      chunkSize: json['chunkSize'] as int,
      length: json['length'] as int,
      metadata: AudioMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      uploadDate: _parseDate(json['uploadDate'] as String),
    );
  }

  /// Convierte el AudioModel a JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'filename': filename,
      'chunkSize': chunkSize,
      'length': length,
      'metadata': metadata.toJson(),
      'uploadDate': uploadDate.toIso8601String(),
    };
  }

  /// Parsea la fecha del formato del servidor
  static DateTime _parseDate(String dateStr) {
    try {
      // Formato: "Mon, 09 Mar 2026 12:29:58 GMT"
      return DateTime.parse(dateStr);
    } catch (e) {
      // Si falla el parse, intentamos con otro formato
      try {
        final parts = dateStr.split(', ')[1].split(' ');
        final day = int.parse(parts[0]);
        final month = _monthToNumber(parts[1]);
        final year = int.parse(parts[2]);
        final timeParts = parts[3].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = int.parse(timeParts[2]);
        
        return DateTime.utc(year, month, day, hour, minute, second);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Convierte el nombre del mes a número
  static int _monthToNumber(String month) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return months[month] ?? 1;
  }

  /// Obtiene la URL del audio
  String getAudioUrl(String baseUrl) {
    return '$baseUrl/get_audio/${metadata.audioId}';
  }

  /// Obtiene la duración del audio en formato legible
  String getFormattedDuration() {
    final seconds = (length / 44100).round(); // Asumiendo 44.1kHz sample rate
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Metadata del audio
class AudioMetadata {
  final String audioId;
  final String routeId;
  final String title;

  AudioMetadata({
    required this.audioId,
    required this.routeId,
    required this.title,
  });

  /// Crea AudioMetadata desde un JSON
  factory AudioMetadata.fromJson(Map<String, dynamic> json) {
    return AudioMetadata(
      audioId: json['audio_id'] as String,
      routeId: json['route_id'] as String,
      title: json['title'] as String,
    );
  }

  /// Convierte el AudioMetadata a JSON
  Map<String, dynamic> toJson() {
    return {
      'audio_id': audioId,
      'route_id': routeId,
      'title': title,
    };
  }
}
