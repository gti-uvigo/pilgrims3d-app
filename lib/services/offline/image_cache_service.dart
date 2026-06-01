import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'offline_storage_service.dart';

/// Servicio para descargar y gestionar caché de imágenes
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final OfflineStorageService _storage = OfflineStorageService();

  /// Descarga una imagen desde una URL y la guarda localmente
  Future<String?> downloadAndCacheImage(
    String imageUrl,
    String imageId,
  ) async {
    try {
      // Verificar si ya está descargada
      final existingPath = await _storage.getImageLocalPath(imageId);
      if (existingPath != null && await File(existingPath).exists()) {
        print('Imagen $imageId ya existe en caché: $existingPath');
        return existingPath;
      }

      // Descargar la imagen
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        print('Error al descargar imagen $imageId: ${response.statusCode}');
        return null;
      }

      // Guardar la imagen localmente
      final localPath = await _saveImageLocally(imageId, response.bodyBytes);
      if (localPath != null) {
        await _storage.registerImage(imageId, localPath);
        print('Imagen $imageId descargada y guardada en: $localPath');
      }

      return localPath;
    } catch (e) {
      print('Error al descargar y cachear imagen $imageId: $e');
      return null;
    }
  }

  /// Guarda los bytes de una imagen en el almacenamiento local
  Future<String?> _saveImageLocally(String imageId, Uint8List bytes) async {
    try {
      // Obtener directorio de documentos de la app
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/cached_images');

      // Crear el directorio si no existe
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Crear ruta del archivo (con extensión por defecto jpg)
      final filePath = path.join(imagesDir.path, '$imageId.jpg');
      final file = File(filePath);

      // Escribir bytes
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      print('Error al guardar imagen localmente: $e');
      return null;
    }
  }

  /// Obtiene una imagen desde el caché local o null si no existe
  Future<File?> getCachedImage(String imageId) async {
    try {
      final localPath = await _storage.getImageLocalPath(imageId);
      if (localPath == null) return null;

      final file = File(localPath);
      if (await file.exists()) {
        return file;
      } else {
        // El archivo fue eliminado, limpiar registro
        print('Archivo de imagen no encontrado para $imageId, limpiando registro');
        return null;
      }
    } catch (e) {
      print('Error al obtener imagen del caché: $e');
      return null;
    }
  }

  /// Descarga múltiples imágenes en paralelo
  Future<Map<String, String?>> downloadMultipleImages(
    Map<String, String> imageUrlsMap,
  ) async {
    final results = <String, String?>{};

    // Dividir en lotes para no saturar la red
    const batchSize = 5;
    final imageIds = imageUrlsMap.keys.toList();

    for (int i = 0; i < imageIds.length; i += batchSize) {
      final batch = imageIds.skip(i).take(batchSize).toList();
      final futures = batch.map((imageId) {
        final url = imageUrlsMap[imageId]!;
        return downloadAndCacheImage(url, imageId).then((path) {
          results[imageId] = path;
          return path;
        });
      }).toList();

      await Future.wait(futures);
    }

    return results;
  }

  /// Elimina una imagen del caché
  Future<void> deleteCachedImage(String imageId) async {
    try {
      final localPath = await _storage.getImageLocalPath(imageId);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error al eliminar imagen del caché: $e');
    }
  }

  /// Limpia todas las imágenes cacheadas
  Future<void> clearImageCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/cached_images');

      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error al limpiar caché de imágenes: $e');
    }
  }

  /// Obtiene el tamaño total de las imágenes cacheadas en MB
  Future<double> getCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/cached_images');

      if (!await imagesDir.exists()) return 0.0;

      int totalBytes = 0;
      await for (final entity in imagesDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }

      return totalBytes / (1024 * 1024); // Convertir a MB
    } catch (e) {
      print('Error al calcular tamaño del caché: $e');
      return 0.0;
    }
  }
}
