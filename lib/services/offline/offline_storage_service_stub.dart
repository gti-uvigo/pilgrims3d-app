/// Stub para web - OfflineStorageService sin funcionalidad
class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  /// Stub - retorna null
  Future<dynamic> getCachedApiResponse(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    return null;
  }

  /// Stub - no hace nada
  Future<void> cacheApiResponse(
    String endpoint,
    Map<String, dynamic> params,
    dynamic response,
  ) async {
    // No-op en web
  }

  /// Stub - retorna false
  Future<bool> isRouteDownloaded(String routeId, String languageId) async {
    return false;
  }

  /// Stub - no hace nada
  Future<void> markRouteAsDownloaded(
    String routeId,
    String routeName,
    String languageId, {
    bool isComplete = true,
  }) async {
    // No-op en web
  }

  /// Stub - retorna lista vacía
  Future<List<Map<String, dynamic>>> getDownloadedRoutes() async {
    return [];
  }

  /// Stub - no hace nada
  Future<void> deleteRouteCached(String routeId, String languageId) async {
    // No-op en web
  }

  /// Stub - no hace nada
  Future<void> clearAllCache() async {
    // No-op en web
  }

  /// Stub - no hace nada
  Future<void> clearCacheForEndpoint(String endpoint) async {
    // No-op en web
  }

  /// Stub - no hace nada
  Future<void> clearCacheForEndpointPattern(String endpointPattern) async {
    // No-op en web
  }
}
