import 'package:pilgrims_3d/presentation/widgets/map/route_endpoint_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pilgrims_3d/presentation/widgets/map/map_current_location_marker.dart';
import 'package:pilgrims_3d/presentation/widgets/map/interest_point_marker.dart';
import 'package:pilgrims_3d/presentation/widgets/map/cached_tile_provider.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';
import 'package:pilgrims_3d/presentation/widgets/map/colored_polyline_helper.dart';

class CustomMap extends StatefulWidget {
  final LatLng currentPosition;
  final MapController mapController;
  final List interestPoints;
  final List<Map<String, dynamic>> routes;
  final List<List<LatLng>> walkingRoute;
  final bool isAllRoutes;
  final VoidCallback? onMapReady;

  /// Si es null, el marcador de posición actual se muestra solo cuando isAllRoutes=false.
  /// Pasar true para forzarlo visible (ej. NearbyRoutesMapScreen).
  final bool? showCurrentLocationMarker;

  /// Si es null, los marcadores de inicio/fin se muestran solo cuando isAllRoutes=false.
  final bool? showRouteEndpoints;

  /// Callback al tocar una ruta (polyline o marcador de inicio/fin).
  /// Si es null y isAllRoutes=true, muestra el tooltip existente.
  final void Function(Map<String, dynamic> route)? onRouteTap;

  /// Puntos de elevación para mostrar rutas con colores según pendiente
  final List<ElevationPoint>? elevationPoints;

  /// Si true, usa colores de pendiente en lugar de color único
  final bool useElevationColors;

  const CustomMap({
    super.key,
    required this.currentPosition,
    required this.mapController,
    required this.interestPoints,
    required this.routes,
    required this.walkingRoute,
    required List<List<LatLng>> routeCoordinates,
    required this.isAllRoutes,
    this.onMapReady,
    this.showCurrentLocationMarker,
    this.showRouteEndpoints,
    this.onRouteTap,
    this.elevationPoints,
    this.useElevationColors = false,
  });

  @override
  State<CustomMap> createState() => _CustomMapState();
}

class _CustomMapState extends State<CustomMap> {
  LatLng? tappedPoint;
  String? tappedTitle;
  bool _hasCentered = false;

  @override
  void didUpdateWidget(CustomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Centrar en el primer punto de la ruta la primera vez que estén listos
    if (!_hasCentered && !widget.isAllRoutes && widget.routes.isNotEmpty) {
      final coordinates = widget.routes[0]['coordinates'] as List<LatLng>?;
      if (coordinates != null && coordinates.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.mapController.move(coordinates.first, 15);
          _hasCentered = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el primer punto de la ruta si existe
    LatLng initialCenter = widget.currentPosition;
    if (!widget.isAllRoutes && widget.routes.isNotEmpty) {
      final coordinates = widget.routes[0]['coordinates'] as List<LatLng>?;
      if (coordinates != null && coordinates.isNotEmpty) {
        initialCenter = coordinates.first;
      }
    }

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: widget.isAllRoutes ? 9 : 15,
        minZoom: 5,
        maxZoom: 18,
        onMapReady: widget.onMapReady,
        onTap: (tapPosition, point) {
          if (!widget.isAllRoutes) return;
          const threshold = 0.001;
          bool found = false;
          Map<String, dynamic>? hitRoute;
          LatLng? hitPoint;
          for (var route in widget.routes) {
            for (var routePoint in route['coordinates'] as List<LatLng>) {
              final distanceLat = (routePoint.latitude - point.latitude).abs();
              final distanceLng =
                  (routePoint.longitude - point.longitude).abs();
              if (distanceLat < threshold && distanceLng < threshold) {
                hitRoute = route;
                hitPoint = routePoint;
                found = true;
                break;
              }
            }
            if (found) break;
          }
          if (found && hitRoute != null) {
            if (widget.onRouteTap != null) {
              widget.onRouteTap!(hitRoute);
            } else {
              setState(() {
                tappedPoint = hitPoint;
                tappedTitle = hitRoute!['title'] ?? 'Ruta';
              });
            }
          } else {
            setState(() {
              tappedPoint = null;
              tappedTitle = null;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pilgrimsapp',
          tileProvider: CachedTileProvider(),
        ),
        PolylineLayer(
          polylines: [
            // Si hay datos de elevación y está activado, usar colores de pendiente
            if (widget.useElevationColors && widget.elevationPoints != null && widget.elevationPoints!.isNotEmpty)
              ...createOptimizedColoredPolylines(widget.elevationPoints!, strokeWidth: 5)
            else
              // Si no, usar el método tradicional
              ...widget.routes
                  .where((r) => (r['coordinates'] as List).isNotEmpty)
                  .map(
                    (r) => Polyline(
                      points: r['coordinates'] as List<LatLng>,
                      color: r['color'] ?? Colors.red,
                      strokeWidth: 5,
                    ),
                  ),
            // Ruta de navegación (en azul)
            if (widget.walkingRoute.isNotEmpty &&
                widget.walkingRoute[0].isNotEmpty)
              Polyline(
                points: widget.walkingRoute[0],
                color: Colors.blue,
                strokeWidth: 4,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (widget.showCurrentLocationMarker ?? !widget.isAllRoutes)
              MapCurrentLocationMarker(
                position: widget.currentPosition,
                context: context,
              ),
            if (widget.showRouteEndpoints ?? !widget.isAllRoutes)
              ...widget.routes
                  .where((r) => (r['coordinates'] as List).isNotEmpty)
                  .expand((r) {
                    final coords = r['coordinates'] as List<LatLng>;
                    return [
                      RouteEndpointMarker(
                        position: coords.first,
                        isStart: true,
                        onTap:
                            widget.onRouteTap != null
                                ? () => widget.onRouteTap!(r)
                                : null,
                      ),
                      RouteEndpointMarker(
                        position: coords.last,
                        isStart: false,
                        onTap:
                            widget.onRouteTap != null
                                ? () => widget.onRouteTap!(r)
                                : null,
                      ),
                    ];
                  }),
            ...() {
              print(
                '🗺️  CustomMap: Renderizando ${widget.interestPoints.length} POIs',
              );
              // Filtrar POIs duplicados por ID
              final uniquePois = <String, dynamic>{};
              for (var point in widget.interestPoints) {
                final id = point['id']?.toString();
                if (id != null && !uniquePois.containsKey(id)) {
                  uniquePois[id] = point;
                }
              }
              print('🗺️  CustomMap: POIs únicos: ${uniquePois.length}');
              return uniquePois.values.map((point) {
                try {
                  return InterestPointMarker(point: point, context: context);
                } catch (e) {
                  print('❌ Error creando marker para POI: $e');
                  print('   POI data: $point');
                  return null;
                }
              }).whereType<Marker>();
            }(),
            if (tappedPoint != null && tappedTitle != null)
              Marker(
                point: tappedPoint!,
                width: 320,
                height: 90,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 120,
                      maxWidth: 320,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Text(
                      tappedTitle!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
