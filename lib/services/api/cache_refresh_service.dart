import 'package:pilgrims_3d/services/offline/offline_storage_service_stub.dart'
    if (dart.library.io) 'package:pilgrims_3d/services/offline/offline_storage_service.dart';

/// Servicio para gestionar la estrategia de caché online/offline
class CacheRefreshService {
  static final CacheRefreshService _instance = CacheRefreshService._internal();
  factory CacheRefreshService() => _instance;
  CacheRefreshService._internal();

  final OfflineStorageService _offlineStorage = OfflineStorageService();

  /// Lista de endpoints que deben refrescarse cuando se pasa de offline a online
  /// o cuando se reinicia la app en modo online
  static const List<String> _refreshableEndpoints = [
    'routes',
    'route_stages',
    'pois_by_route',
    'pois_around_route',
    'languages',
    'route_types',
    'pois_types',
    'poi',
    'my_routes',
    'route_base_coordinates',
    'route_locations',
  ];

  /// Limpia el caché de todos los endpoints que necesitan refrescarse
  /// Se llama cuando:
  /// 1. La app se inicia y está online
  /// 2. Se detecta cambio de offline a online
  Future<void> clearRefreshableCache() async {
    try {
      for (final endpoint in _refreshableEndpoints) {
        await _clearCacheForEndpoint(endpoint);
      }
      print('✅ Caché limpiado para endpoints refrescables');
    } catch (e) {
      print('❌ Error limpiando caché: $e');
    }
  }

  /// Limpia el caché de un endpoint específico
  Future<void> _clearCacheForEndpoint(String endpoint) async {
    try {
      await _offlineStorage.clearCacheForEndpoint(endpoint);
    } catch (e) {
      print('❌ Error limpiando caché para $endpoint: $e');
    }
  }

  /// Limpia caché selectivo - solo para endpoints específicos
  Future<void> clearCacheForEndpoints(List<String> endpoints) async {
    try {
      for (final endpoint in endpoints) {
        if (_refreshableEndpoints.contains(endpoint)) {
          await _clearCacheForEndpoint(endpoint);
        }
      }
      print('✅ Caché limpiado para endpoints específicos: $endpoints');
    } catch (e) {
      print('❌ Error limpiando caché específico: $e');
    }
  }

  /// Verifica si un endpoint debe refrescarse
  bool shouldRefreshEndpoint(String endpoint) {
    return _refreshableEndpoints.contains(endpoint);
  }
}