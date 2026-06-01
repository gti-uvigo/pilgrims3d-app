import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Servicio para descargar y cachear tiles del mapa para uso offline
class MapTileCacheService {
  static final MapTileCacheService _instance = MapTileCacheService._internal();
  factory MapTileCacheService() => _instance;
  MapTileCacheService._internal();

  static const String _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const int _minZoom = 10; // Zoom mínimo para descargar
  static const int _maxZoom = 15; // Zoom máximo para descargar
  
  /// Obtiene el directorio donde se guardan las tiles
  Future<Directory> _getTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory(p.join(appDir.path, 'map_tiles'));
    
    if (!await tilesDir.exists()) {
      await tilesDir.create(recursive: true);
    }
    
    return tilesDir;
  }

  /// Convierte coordenadas lat/lng a números de tile para un zoom específico
  Point<int> _latLngToTile(double lat, double lng, int zoom) {
    final n = pow(2, zoom).toInt();
    final x = ((lng + 180) / 360 * n).floor();
    final latRad = lat * pi / 180;
    final y = ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();
    return Point(x, y);
  }

  /// Calcula el bounding box de tiles necesarios para cubrir una ruta
  Map<int, Set<Point<int>>> _calculateTilesForRoute(List<LatLng> routeCoordinates) {
    if (routeCoordinates.isEmpty) return {};

    final tilesPerZoom = <int, Set<Point<int>>>{};

    // Para cada nivel de zoom
    for (int zoom = _minZoom; zoom <= _maxZoom; zoom++) {
      final tiles = <Point<int>>{};

      // Agregar tiles para cada punto de la ruta
      for (final coord in routeCoordinates) {
        final tile = _latLngToTile(coord.latitude, coord.longitude, zoom);
        tiles.add(tile);
        
        // Agregar tiles adyacentes para un buffer (tiles vecinos)
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            tiles.add(Point(tile.x + dx, tile.y + dy));
          }
        }
      }

      tilesPerZoom[zoom] = tiles;
    }

    return tilesPerZoom;
  }

  /// Descarga una tile individual
  Future<bool> _downloadTile(int zoom, int x, int y) async {
    try {
      final tilesDir = await _getTilesDirectory();
      final tilePath = p.join(tilesDir.path, '$zoom', '$x', '$y.png');
      final tileFile = File(tilePath);

      // Si ya existe, no descargar
      if (await tileFile.exists()) {
        return true;
      }

      // Crear directorios si no existen
      await tileFile.parent.create(recursive: true);

      // Descargar tile
      final url = _tileUrlTemplate
          .replaceAll('{z}', zoom.toString())
          .replaceAll('{x}', x.toString())
          .replaceAll('{y}', y.toString());

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        await tileFile.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        debugPrint('Error descargando tile $zoom/$x/$y: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error descargando tile $zoom/$x/$y: $e');
      return false;
    }
  }

  /// Descarga todas las tiles necesarias para una ruta
  /// Retorna el progreso como un valor entre 0.0 y 1.0
  Future<void> downloadTilesForRoute(
    List<LatLng> routeCoordinates, {
    Function(double progress, int downloaded, int total)? onProgress,
  }) async {
    if (routeCoordinates.isEmpty) {
      debugPrint('No hay coordenadas para descargar tiles');
      return;
    }

    debugPrint('Calculando tiles necesarias para la ruta...');
    final tilesPerZoom = _calculateTilesForRoute(routeCoordinates);
    
    // Calcular total de tiles
    int totalTiles = 0;
    for (final tiles in tilesPerZoom.values) {
      totalTiles += tiles.length;
    }

    debugPrint('Total de tiles a descargar: $totalTiles');
    
    if (totalTiles == 0) {
      onProgress?.call(1.0, 0, 0);
      return;
    }

    int downloadedTiles = 0;
    int successfulDownloads = 0;

    // Descargar tiles por nivel de zoom
    for (final entry in tilesPerZoom.entries) {
      final zoom = entry.key;
      final tiles = entry.value;

      debugPrint('Descargando ${tiles.length} tiles para zoom $zoom');

      // Descargar en lotes de 5 tiles simultáneas
      final tilesList = tiles.toList();
      for (int i = 0; i < tilesList.length; i += 5) {
        final batch = tilesList.skip(i).take(5).toList();
        
        await Future.wait(
          batch.map((tile) async {
            final success = await _downloadTile(zoom, tile.x, tile.y);
            if (success) successfulDownloads++;
            downloadedTiles++;
            
            // Reportar progreso
            final progress = downloadedTiles / totalTiles;
            onProgress?.call(progress, downloadedTiles, totalTiles);
          }),
        );

        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    debugPrint('Descarga de tiles completada: $successfulDownloads/$totalTiles exitosas');
  }

  /// Obtiene el path local de una tile si existe en caché
  Future<String?> getTileLocalPath(int zoom, int x, int y) async {
    try {
      final tilesDir = await _getTilesDirectory();
      final tilePath = p.join(tilesDir.path, '$zoom', '$x', '$y.png');
      final tileFile = File(tilePath);

      if (await tileFile.exists()) {
        return tilePath;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error obteniendo path de tile $zoom/$x/$y: $e');
      return null;
    }
  }

  /// Limpia todas las tiles del caché
  Future<void> clearTileCache() async {
    try {
      final tilesDir = await _getTilesDirectory();
      
      if (await tilesDir.exists()) {
        await tilesDir.delete(recursive: true);
        debugPrint('Caché de tiles limpiado');
      }
    } catch (e) {
      debugPrint('Error al limpiar caché de tiles: $e');
    }
  }

  /// Obtiene el tamaño del caché de tiles en MB
  Future<double> getCacheSize() async {
    try {
      final tilesDir = await _getTilesDirectory();
      
      if (!await tilesDir.exists()) {
        return 0.0;
      }

      int totalSize = 0;
      await for (final entity in tilesDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize / (1024 * 1024); // Convertir a MB
    } catch (e) {
      debugPrint('Error al calcular tamaño de caché: $e');
      return 0.0;
    }
  }
}
