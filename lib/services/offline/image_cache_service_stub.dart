import 'dart:io';

/// Stub para web - ImageCacheService sin funcionalidad
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// Stub - retorna null
  Future<File?> getCachedImage(String imageId) async {
    return null;
  }

  /// Stub - no hace nada
  Future<void> downloadAndCacheImage(String url, String imageId) async {
    // No-op en web
  }

  /// Stub - no hace nada
  Future<void> downloadMultipleImages(Map<String, String> imageUrls) async {
    // No-op en web
  }

  /// Stub - no hace nada
  Future<void> clearCache() async {
    // No-op en web
  }
}
