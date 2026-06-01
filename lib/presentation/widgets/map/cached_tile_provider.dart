import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pilgrims_3d/services/offline/map_tile_cache_service.dart';

/// TileProvider personalizado que usa el caché local de tiles
class CachedTileProvider extends TileProvider {
  final MapTileCacheService _cacheService = MapTileCacheService();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // En web, usar el NetworkTileProvider por defecto
    if (kIsWeb) {
      return NetworkImage(
        options.urlTemplate!
            .replaceAll('{z}', coordinates.z.round().toString())
            .replaceAll('{x}', coordinates.x.round().toString())
            .replaceAll('{y}', coordinates.y.round().toString()),
      );
    }
    // En móvil, usar caché local
    return _CachedNetworkImageProvider(
      coordinates,
      options,
      _cacheService,
    );
  }
}

class _CachedNetworkImageProvider extends ImageProvider<_CachedNetworkImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final MapTileCacheService cacheService;

  _CachedNetworkImageProvider(
    this.coordinates,
    this.options,
    this.cacheService,
  );

  @override
  Future<_CachedNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(_CachedNetworkImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'CachedTile(${coordinates.z}/${coordinates.x}/${coordinates.y})',
    );
  }

  Future<ui.Codec> _loadAsync(_CachedNetworkImageProvider key, ImageDecoderCallback decode) async {
    try {
      // Primero intentar cargar desde caché local
      final cachedPath = await cacheService.getTileLocalPath(
        coordinates.z.round(),
        coordinates.x.round(),
        coordinates.y.round(),
      );

      Uint8List bytes;

      if (cachedPath != null) {
        // Cargar desde archivo local
        final file = File(cachedPath);
        bytes = await file.readAsBytes();
        debugPrint('Tile cargada desde caché: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
      } else {
        // Si no está en caché, descargar desde red
        final url = options.urlTemplate!
            .replaceAll('{z}', coordinates.z.round().toString())
            .replaceAll('{x}', coordinates.x.round().toString())
            .replaceAll('{y}', coordinates.y.round().toString());

        final uri = Uri.parse(url);
        final response = await HttpClient().getUrl(uri);
        final httpResponse = await response.close();
        
        bytes = await consolidateHttpClientResponseBytes(httpResponse);
        debugPrint('Tile descargada desde red: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      debugPrint('Error cargando tile ${coordinates.z}/${coordinates.x}/${coordinates.y}: $e');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CachedNetworkImageProvider &&
        other.coordinates == coordinates &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(coordinates, options);
}
