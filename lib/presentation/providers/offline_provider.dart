import 'package:flutter/foundation.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/offline/offline_storage_service.dart';
import 'package:pilgrims_3d/services/offline/image_cache_service.dart';
import 'package:pilgrims_3d/services/offline/map_tile_cache_service.dart';
import 'package:pilgrims_3d/core/config/env.dart';

/// Provider para gestionar el estado de las descargas offline
class OfflineProvider with ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService();
  final ImageCacheService _imageCache = ImageCacheService();
  final MapTileCacheService _mapTileCache = MapTileCacheService();

  // Estado de la descarga
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadMessage = '';

  // Rutas descargadas
  final Map<String, bool> _downloadedRoutes = {};

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadMessage => _downloadMessage;
  Map<String, bool> get downloadedRoutes => _downloadedRoutes;

  /// Inicializa el provider cargando las rutas descargadas
  Future<void> initialize() async {
    await _loadDownloadedRoutes();
    await _ensureEssentialDataCached();
  }

  /// Asegura que los datos esenciales (idiomas y tipos de ruta) estén en caché
  Future<void> _ensureEssentialDataCached() async {
    try {
      debugPrint('Verificando datos esenciales en caché...');

      // Descargar idiomas si no están en caché
      final languages = await getLanguages();
      if (languages.isNotEmpty) {
        debugPrint('✅ Idiomas cacheados: ${languages.length} idiomas');
      }

      // Descargar tipos de ruta si no están en caché
      final routeTypes = await getRouteTypes();
      if (routeTypes.isNotEmpty) {
        debugPrint('✅ Tipos de ruta cacheados: ${routeTypes.length} tipos');
      }
    } catch (e) {
      debugPrint('Error al cachear datos esenciales: $e');
    }
  }

  /// Carga la lista de rutas ya descargadas
  Future<void> _loadDownloadedRoutes() async {
    try {
      final routes = await _storage.getDownloadedRoutes();
      _downloadedRoutes.clear();
      for (var route in routes) {
        final key = '${route['route_id']}_${route['language_id']}';
        _downloadedRoutes[key] = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar rutas descargadas: $e');
    }
  }

  /// Verifica si una ruta está descargada
  bool isRouteDownloaded(String routeId, String languageId) {
    final key = '${routeId}_$languageId';
    return _downloadedRoutes[key] ?? false;
  }

  /// Descarga una ruta completa con sus etapas, POIs e imágenes
  Future<bool> downloadRoute(
    String routeId,
    String routeName,
    String languageId,
  ) async {
    if (_isDownloading) {
      debugPrint('Ya hay una descarga en curso');
      return false;
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadMessage = 'Iniciando descarga...';
    notifyListeners();

    try {
      // 1. Descargar información de las etapas
      _downloadMessage = 'Descargando etapas...';
      _downloadProgress = 0.1;
      notifyListeners();

      final daysData = await getDaysInformation(routeId, languageId);
      if (daysData.isEmpty) {
        throw Exception('No se pudo obtener información de las etapas');
      }

      debugPrint('📊 Total de etapas descargadas: ${daysData.length}');

      // 2. Descargar POIs de cada etapa y sus imágenes
      _downloadMessage = 'Descargando puntos de interés...';
      _downloadProgress = 0.3;
      notifyListeners();

      final allPois = <dynamic>[];
      final imageIds = <String>[];

      for (var i = 0; i < daysData.length; i++) {
        final day = daysData[i];
        final pois = day['points_of_interest'] as List? ?? [];
        debugPrint('   Etapa ${i + 1}: ${pois.length} POIs');
        allPois.addAll(pois);

        // Recopilar IDs de imágenes
        for (var poi in pois) {
          if (poi['image_id'] != null) {
            final imageId = poi['image_id'].toString();
            if (!imageIds.contains(imageId)) {
              imageIds.add(imageId);
              debugPrint('      - Imagen agregada: $imageId');
            }
          }
        }
      }

      debugPrint(
        '✅ Total POIs: ${allPois.length}, Total imágenes únicas: ${imageIds.length}',
      );

      // 2.5. Descargar descripciones de POIs
      _downloadMessage =
          'Descargando descripciones de POIs (${allPois.length})...';
      _downloadProgress = 0.4;
      notifyListeners();

      debugPrint('📝 Descargando descripciones de ${allPois.length} POIs...');
      for (var i = 0; i < allPois.length; i++) {
        final poi = allPois[i];
        if (poi['id'] != null) {
          try {
            await moreInfoPois(poi['id'].toString(), languageId);
            if ((i + 1) % 10 == 0) {
              debugPrint(
                '   Progreso descripciones: ${i + 1}/${allPois.length}',
              );
            }
          } catch (e) {
            debugPrint(
              'Error al descargar descripción del POI ${poi['id']}: $e',
            );
          }
        }
      }
      debugPrint('✅ Descripciones descargadas');

      // 3. Descargar imágenes en lotes
      _downloadMessage = 'Descargando imágenes (${imageIds.length})...';
      _downloadProgress = 0.5;
      notifyListeners();

      debugPrint('🖼️  Descargando ${imageIds.length} imágenes...');
      final imageUrls = <String, String>{};
      for (var imageId in imageIds) {
        imageUrls[imageId] = '$baseUrl/images/$imageId';
      }

      // Descargar imágenes
      await _imageCache.downloadMultipleImages(imageUrls);
      debugPrint('✅ Imágenes descargadas');

      // 4. Descargar tiles del mapa
      _downloadMessage = 'Descargando mapa de la ruta...';
      _downloadProgress = 0.65;
      notifyListeners();

      // Obtener coordenadas base de la ruta para descargar tiles
      try {
        final baseCoords = await fetchBaseRouteCoordinates(routeId);
        if (baseCoords.isNotEmpty) {
          final allCoords = baseCoords.expand((list) => list).toList();
          debugPrint(
            'Descargando tiles del mapa para ${allCoords.length} puntos',
          );

          await _mapTileCache.downloadTilesForRoute(
            allCoords,
            onProgress: (progress, downloaded, total) {
              // Actualizar progreso de tiles (ocupa 15% del progreso total: 0.65 - 0.80)
              _downloadProgress = 0.65 + (progress * 0.15);
              _downloadMessage =
                  'Descargando mapa ($downloaded/$total tiles)...';
              notifyListeners();
            },
          );
        }
      } catch (e) {
        debugPrint('Error al descargar tiles del mapa: $e');
      }

      // 5. Descargar datos del mapa (POIs, etc.)
      _downloadMessage = 'Descargando datos del mapa...';
      _downloadProgress = 0.78;
      notifyListeners();

      // Descargar coordenadas base de la ruta (all_route completa)
      try {
        await fetchBaseRouteCoordinates(routeId);
        debugPrint('✅ Coordenadas base de ruta descargadas');
      } catch (e) {
        debugPrint('Error al descargar coordenadas base de ruta: $e');
      }

      // Descargar datos de elevación de la ruta
      _downloadMessage = 'Descargando perfil de elevación...';
      _downloadProgress = 0.80;
      notifyListeners();

      try {
        await fetchRouteElevationData(routeId);
        debugPrint('✅ Datos de elevación de ruta descargados');
      } catch (e) {
        debugPrint('Error al descargar datos de elevación de ruta: $e');
      }

      // Descargar POIs de la ruta completa (todos los POIs principales)
      try {
        final routePois = await fetchInterestPoints(routeId, languageId);
        debugPrint(
          '✅ POIs de la ruta completa descargados: ${routePois.length} POIs',
        );

        // Descargar imágenes de los POIs de la ruta que no se hayan descargado aún
        final routePoiImageUrls = <String, String>{};
        for (final poi in routePois) {
          if (poi['image_id'] != null) {
            final imgId = poi['image_id'].toString();
            if (!imageIds.contains(imgId)) {
              imageIds.add(imgId);
              routePoiImageUrls[imgId] = '$baseUrl/images/$imgId';
            }
          }
        }
        if (routePoiImageUrls.isNotEmpty) {
          debugPrint(
            '🖼️  Descargando ${routePoiImageUrls.length} imágenes adicionales de POIs de ruta...',
          );
          await _imageCache.downloadMultipleImages(routePoiImageUrls);
          debugPrint('✅ Imágenes adicionales de POIs de ruta descargadas');
        }
      } catch (e) {
        debugPrint('Error al descargar POIs de la ruta completa: $e');
      }

      // Descargar POIs alrededor de la ruta
      try {
        await get_pois_around_a_route(routeId, languageId);
        debugPrint('✅ POIs alrededor de la ruta descargados');
      } catch (e) {
        debugPrint('Error al descargar POIs alrededor de ruta: $e');
      }

      // 5. Descargar tipos de POIs
      _downloadMessage = 'Descargando tipos de POIs...';
      _downloadProgress = 0.85;
      notifyListeners();

      await getPoisTypes(languageId);

      // 5.5. Asegurar datos esenciales para pantalla principal
      _downloadMessage = 'Cacheando tipos de ruta e idiomas...';
      _downloadProgress = 0.90;
      notifyListeners();

      await getRouteTypes();
      await getLanguages();

      // 5.6. Cachear listas de rutas por tipo/subtipo (pantalla principal offline)
      _downloadMessage = 'Cacheando listas de rutas...';
      _downloadProgress = 0.94;
      notifyListeners();

      try {
        final routeTypes = await getRouteTypes();
        for (final routeType in routeTypes) {
          final subtypes = routeType['subtypes'] as List? ?? [];
          if (subtypes.isEmpty) continue;
          for (final subtype in subtypes) {
            final subtypeName = subtype['name']?.toString();
            if (subtypeName == null || subtypeName.isEmpty) continue;
            await getCardInformation(
              routeType['id'].toString(),
              subtypeName,
              languageId,
            );
          }
        }
      } catch (e) {
        debugPrint('Error al cachear listas de rutas: $e');
      }

      // 6. Marcar ruta como descargada
      await _storage.markRouteAsDownloaded(
        routeId,
        routeName,
        languageId,
        isComplete: true,
      );

      _downloadProgress = 1.0;
      _downloadMessage = 'Descarga completada';

      // Actualizar estado local
      final key = '${routeId}_$languageId';
      _downloadedRoutes[key] = true;

      notifyListeners();

      await Future.delayed(const Duration(seconds: 1));

      return true;
    } catch (e) {
      debugPrint('Error al descargar ruta: $e');
      _downloadMessage = 'Error en la descarga: $e';
      notifyListeners();
      return false;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadMessage = '';
      notifyListeners();
    }
  }

  /// Elimina una ruta descargada
  Future<bool> deleteDownloadedRoute(String routeId, String languageId) async {
    try {
      await _storage.deleteRouteCached(routeId, languageId);

      final key = '${routeId}_$languageId';
      _downloadedRoutes.remove(key);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar ruta: $e');
      return false;
    }
  }

  /// Limpia toda la caché
  Future<void> clearAllCache() async {
    try {
      await _storage.clearAllCache();
      await _imageCache.clearImageCache();
      await _mapTileCache.clearTileCache();

      _downloadedRoutes.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al limpiar caché: $e');
    }
  }

  /// Obtiene el tamaño total de la caché en MB
  Future<double> getCacheSize() async {
    try {
      final dbSize = await _storage.getCacheSize();
      final imageSize = await _imageCache.getCacheSize();
      final tileSize = await _mapTileCache.getCacheSize();
      return dbSize + imageSize + tileSize;
    } catch (e) {
      debugPrint('Error al obtener tamaño de caché: $e');
      return 0.0;
    }
  }
}
