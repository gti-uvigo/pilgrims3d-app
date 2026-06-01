import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Servicio de caché en memoria para modelos 3D durante la sesión de la app
class ModelCacheService {
  // Singleton pattern
  static final ModelCacheService _instance = ModelCacheService._internal();
  factory ModelCacheService() => _instance;
  ModelCacheService._internal();

  // Caché en memoria: URL -> URL/ruta (para web se mantiene la URL original)
  final Map<String, String> _memoryCache = {};

  // Estado de descarga para evitar descargas duplicadas
  final Map<String, Future<String>> _downloadingModels = {};

  // Progreso de descarga: URL -> porcentaje (0.0 - 1.0)
  final Map<String, double> _downloadProgress = {};

  /// Obtiene la ruta del modelo desde la caché o lo descarga
  Future<String> getModelPath(
    String modelUrl, [
    Function(double)? onProgress,
  ]) async {
    // Si ya está en caché en memoria, retornar inmediatamente
    if (_memoryCache.containsKey(modelUrl)) {
      debugPrint('✅ Modelo encontrado en caché: $modelUrl');
      return _memoryCache[modelUrl]!;
    }

    // Si ya se está descargando, esperar a que termine
    if (_downloadingModels.containsKey(modelUrl)) {
      debugPrint('⏳ Esperando descarga en progreso: $modelUrl');
      return await _downloadingModels[modelUrl]!;
    }

    // Iniciar nueva descarga
    debugPrint('📥 Descargando modelo: $modelUrl');
    final downloadFuture = _downloadModel(modelUrl, onProgress);
    _downloadingModels[modelUrl] = downloadFuture;

    try {
      final path = await downloadFuture;
      _memoryCache[modelUrl] = path;
      return path;
    } finally {
      _downloadingModels.remove(modelUrl);
      _downloadProgress.remove(modelUrl);
    }
  }

  /// Descarga el modelo y lo guarda en el almacenamiento temporal
  /// En web, simplemente retorna la URL original ya que no podemos guardar archivos localmente
  Future<String> _downloadModel(
    String modelUrl, [
    Function(double)? onProgress,
  ]) async {
    try {
      // En web, no podemos usar path_provider, así que retornamos la URL directamente
      if (kIsWeb) {
        debugPrint('🌐 Web detectado: usando URL directa para $modelUrl');
        // Verificar que la URL sea accesible
        final response = await http.head(Uri.parse(modelUrl));
        if (response.statusCode == 200) {
          debugPrint('✅ Modelo accesible: $modelUrl');
          onProgress?.call(1.0);
          return modelUrl;
        } else {
          throw Exception('Error al acceder al modelo: ${response.statusCode}');
        }
      }

      // Para plataformas nativas (Android, iOS, etc.)
      // Crear nombre de archivo único basado en la URL
      final fileName = _generateFileName(modelUrl);

      // Usar directorio de documentos de la app para AR (en lugar de temporal)
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      final filePath = '${modelsDir.path}/$fileName';
      final file = File(filePath);

      // Si el archivo ya existe en disco, usarlo
      if (await file.exists()) {
        debugPrint('📁 Modelo ya existe en disco: $filePath');
        onProgress?.call(1.0);
        return filePath;
      }

      // Descargar el archivo con progreso
      debugPrint('🌐 Descargando desde: $modelUrl');
      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        var receivedBytes = 0;
        final bytes = <int>[];

        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;

          if (contentLength > 0) {
            final progress = receivedBytes / contentLength;
            _downloadProgress[modelUrl] = progress;
            onProgress?.call(progress);
            debugPrint('📊 Progreso: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }

        await file.writeAsBytes(bytes);
        debugPrint('✅ Modelo descargado exitosamente: $filePath');
        onProgress?.call(1.0);
        return filePath;
      } else {
        throw Exception('Error al descargar el modelo: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error al descargar modelo: $e');
      rethrow;
    }
  }

  /// Genera un nombre de archivo único basado en la URL
  String _generateFileName(String url) {
    // Usar hash MD5 de la URL para generar un nombre único
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes);

    // Extraer la extensión del archivo original
    final uri = Uri.parse(url);
    final extension = uri.path.split('.').last.toLowerCase();
    final validExtensions = ['glb', 'gltf'];
    final ext = validExtensions.contains(extension) ? extension : 'glb';

    return 'model_$hash.$ext';
  }

  /// Verifica si un modelo está en la caché
  bool isModelCached(String modelUrl) {
    return _memoryCache.containsKey(modelUrl);
  }

  /// Obtiene el tamaño actual de la caché
  int getCacheSize() {
    return _memoryCache.length;
  }

  /// Obtiene el progreso de descarga de un modelo
  double getDownloadProgress(String modelUrl) {
    return _downloadProgress[modelUrl] ?? 0.0;
  }

  /// Limpia la caché (se llamará automáticamente al cerrar la app)
  void clearCache() {
    debugPrint(
      '🗑️ Limpiando caché de modelos (${_memoryCache.length} modelos)',
    );
    _memoryCache.clear();
    _downloadingModels.clear();
    _downloadProgress.clear();
  }

  /// Pre-carga un modelo en segundo plano
  Future<void> preloadModel(String modelUrl) async {
    if (!_memoryCache.containsKey(modelUrl)) {
      try {
        await getModelPath(modelUrl);
        debugPrint('✅ Modelo pre-cargado: $modelUrl');
      } catch (e) {
        debugPrint('⚠️ Error al pre-cargar modelo: $e');
      }
    }
  }
}
