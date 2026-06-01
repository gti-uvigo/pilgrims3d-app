import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/map/custom_map.dart';
import 'package:pilgrims_3d/presentation/widgets/map/map_floating_buttons.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:provider/provider.dart';

class NearbyRoutesMapScreen extends StatefulWidget {
  final String languageId;
  final double distanceKm;

  const NearbyRoutesMapScreen({
    super.key,
    required this.languageId,
    this.distanceKm = 2.0,
  });

  @override
  State<NearbyRoutesMapScreen> createState() => _NearbyRoutesMapScreenState();
}

class _NearbyRoutesMapScreenState extends State<NearbyRoutesMapScreen> {
  final MapController _mapController = MapController();
  bool _isExpanded = false;
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;
  String? _error;

  final List<Color> _routeColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.cyan,
    Colors.indigo,
    Colors.lime,
    Colors.pink,
    Colors.amber,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.lightBlue,
    Colors.lightGreen,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadNearbyRoutes();
    });
  }

  /// Obtiene la posición actual usando el helper compartido.
  /// Si tarda más de 8 s, intenta obtener la última posición conocida.
  Future<Position> _getPosition() async {
    try {
      return await determinePosition().timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) return last;
          throw Exception('Tiempo de espera agotado al obtener la ubicación.');
        },
      );
    } catch (_) {
      // Último recurso: posición cacheada
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// Muestra un diálogo preguntando si el usuario quiere ver la ruta seleccionada.
  void _showRouteDialog(BuildContext context, Map<String, dynamic> route) {
    final routeId = route['route_id']?.toString() ?? '';
    final routeName = route['title']?.toString() ?? '';
    if (routeId.isEmpty) return;

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(routeName.isNotEmpty ? routeName : 'Ruta'),
            content: const Text('¿Deseas ver los detalles de esta ruta?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(
                    '/route',
                    extra: {'routeId': routeId, 'routeName': routeName},
                  );
                },
                child: const Text('Ver ruta'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadNearbyRoutes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pos = await _getPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentPosition = userLatLng;
      });

      // Centrar el mapa en la posición del usuario en cuanto la tenemos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(userLatLng, 13);
        } catch (_) {}
      });

      final response = await api.getRoutesNearbyALocation(
        pos.latitude,
        pos.longitude,
        widget.languageId,
        distanceKm: widget.distanceKm,
      );

      final List routes = response as List? ?? [];

      // Debug: mostrar estructura del primer elemento
      if (routes.isNotEmpty) {
        print('🔍 Estructura ruta cercana[0]: ${routes[0]}');
      }

      final List<Map<String, dynamic>> parsedRoutes =
          routes.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;
            // Las coordenadas vienen en r["locations"]["all_points"]
            final locations = r["locations"] as Map<String, dynamic>? ?? {};
            final rawCoords =
                (locations["all_points"] ??
                        r["route"] ??
                        r["coordinates"] ??
                        r["route_coordinates"] ??
                        [])
                    as List;
            final List<LatLng> coords =
                rawCoords
                    .map((pair) {
                      try {
                        final lon = (pair[0] as num).toDouble();
                        final lat = (pair[1] as num).toDouble();
                        return LatLng(lat, lon);
                      } catch (e) {
                        print('⚠️ Error parseando coordenada: $pair → $e');
                        return null;
                      }
                    })
                    .whereType<LatLng>()
                    .toList();
            print('  → Ruta ${r["route_id"]}: ${coords.length} puntos');
            return {
              "route_id": r["route_id"],
              "route_type": r["route_type"],
              "title": r["title"],
              "coordinates": coords,
              "color": _routeColors[index % _routeColors.length],
            };
          }).toList();

      setState(() {
        _routes = parsedRoutes;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error al cargar rutas cercanas: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${localeProvider.translate('routes')} (${widget.distanceKm.toStringAsFixed(0)} km)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyRoutes,
            tooltip: localeProvider.translate('retry'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // El mapa se renderiza siempre para que los tiles carguen desde el inicio
          CustomMap(
            currentPosition:
                _currentPosition ?? const LatLng(42.88064, -8.54439),
            mapController: _mapController,
            interestPoints: [],
            routes: _routes,
            routeCoordinates: [],
            walkingRoute: [],
            isAllRoutes: true,
            showCurrentLocationMarker: _currentPosition != null,
            showRouteEndpoints: true,
            onRouteTap: (route) => _showRouteDialog(context, route),
            onMapReady: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 13);
              }
            },
          ),

          // Overlay de carga mientras se obtiene posición o rutas
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Banner de error
          if (_error != null && !_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 40,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localeProvider.translate('location_permission_denied'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadNearbyRoutes,
                        icon: const Icon(Icons.refresh),
                        label: Text(localeProvider.translate('retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Mensaje de sin rutas (solo cuando carga terminó sin error)
          if (!_isLoading && _routes.isEmpty && _error == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${localeProvider.translate('no_routes_available')} ${widget.distanceKm.toStringAsFixed(0)} km',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Botones flotantes
          Positioned(
            bottom: 20,
            right: 20,
            child: MapFloatingButtons(
              isExpanded: _isExpanded,
              onToggleExpand: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              onLocatePressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 13);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
