import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/widgets/map/custom_map.dart';
import 'package:pilgrims_3d/presentation/widgets/map/map_floating_buttons.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';
import 'package:pilgrims_3d/presentation/widgets/route_info_dialog.dart';
import 'package:pilgrims_3d/presentation/widgets/elevation_color_legend.dart';

class OneRouteMapScreen extends StatefulWidget {
  final String routeId;
  final String routeName;
  final List pois;

  const OneRouteMapScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.pois,
  });

  @override
  State<OneRouteMapScreen> createState() => _OneRouteMapScreenState();
}

class _OneRouteMapScreenState extends State<OneRouteMapScreen> {
  LatLng _currentPosition = LatLng(0, 0);
  List<List<LatLng>> _routeCoordinates = [];
  List<List<LatLng>> _walkingRoute = [];
  List _interestPoints = [];
  List _poisAroundRoute = [];
  final MapController _mapController = MapController();
  bool _isExpanded = false;
  bool _showFullRoute = true;
  bool _poisAroundLoaded = false;
  bool _showPoisAround = false;
  bool _isLoadingRoute = true; // Estado de carga de ruta
  
  // Elevation data
  List<ElevationPoint> _elevationPoints = [];
  final bool _useElevationColors = true; // Activado por defecto
  bool _elevationDataLoaded = false;

  late LocaleProvider localeProvider;
  final Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      String langCode = localeProvider.currentLangId;
      
      // Obtener ubicación primero (rápido)
      _getCurrentLocation();
      
      // Cargar coordenadas base (desde caché si está disponible)
      _loadRouteCoordinates();
      
      // Cargar datos de elevación en segundo plano
      _loadElevationData();
      
      // Cargar POIs en segundo plano
      _getInterestPoints(langCode);
      
      // Cargar POIs alrededor en último lugar (no crítico)
      _getPoisAroundRoute(langCode);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await determinePosition();
      final newPosition = LatLng(position.latitude, position.longitude);
      
      // Solo actualizar si hay cambio significativo
      if (_currentPosition.latitude == 0 || 
          (_currentPosition.latitude - newPosition.latitude).abs() > 0.0001) {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
          });
        }
      }
      
      // Intentar recargar con navegación si tenemos ubicación
      if (_routeCoordinates.isEmpty && mounted) {
        await _loadRouteCoordinates();
      }
      
      if (!kIsWeb) {
        updateUserCoords(_currentPosition.latitude, _currentPosition.longitude)
            .catchError((e) => debugPrint('Error updating coords: $e'));
      }
    } catch (e) {
      debugPrint('Error al obtener la ubicación: $e');
    }
  }

  Future<void> _loadRouteCoordinates() async {
    // Primero intentar cargar las coordenadas base de la ruta (para modo offline)
    final baseCoordinates = await fetchBaseRouteCoordinates(widget.routeId);
    
    if (baseCoordinates.isNotEmpty && mounted) {
      setState(() {
        _routeCoordinates = baseCoordinates;
        _walkingRoute = [];
        _isLoadingRoute = false;
      });
      return;
    }
    
    // Si no hay coordenadas base, intentar obtener coordenadas específicas (solo en modo online)
    if (widget.pois.isNotEmpty) {
      final firstPoi = widget.pois.first;
      final lastPoi = widget.pois.last;
      
      final startPos = LatLng(firstPoi['latitude'], firstPoi['longitude']);
      final endPos = LatLng(lastPoi['latitude'], lastPoi['longitude']);
      
      try {
        final coordinates = await fetchRouteCoordinates(
          widget.routeId,
          startPos,
          endPos,
        );
        if (mounted) {
          setState(() {
            _routeCoordinates = coordinates["all_coordinates"] ?? [];
            _walkingRoute = coordinates["walking"] ?? [];
            _isLoadingRoute = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Error al cargar coordenadas específicas de etapa: $e');
      }
    }
    
    // Si no hay coordenadas y tenemos ubicación del usuario, calcular navegación
    if (_currentPosition.latitude != 0 && _currentPosition.longitude != 0 && widget.pois.isNotEmpty) {
      final endPosition = LatLng(widget.pois[0]['latitude'], widget.pois[0]['longitude']);
      try {
        final coordinates = await fetchRouteCoordinates(
          widget.routeId,
          _currentPosition,
          endPosition,
        );
        if (mounted) {
          setState(() {
            _routeCoordinates = coordinates["all_coordinates"] ?? [];
            _walkingRoute = coordinates["walking"] ?? [];
            _isLoadingRoute = false;
          });
        }
      } catch (e) {
        debugPrint('Error al cargar coordenadas de navegación: $e');
        if (mounted) {
          setState(() {
            _isLoadingRoute = false;
          });
        }
      }
    } else {
      // Si no hay coordenadas disponibles, marcar como cargado de todas formas
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  Future<void> _getInterestPoints(String langCode) async {
    try {
      debugPrint('🔍 Cargando POIs de la ruta: ${widget.routeId}, idioma: $langCode');
      final points = await fetchInterestPoints(widget.routeId, langCode);
      debugPrint('✅ POIs de la ruta cargados: ${points.length} POIs');
      if (mounted) {
        setState(() {
          _interestPoints = points;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar los puntos de interés: $e');
    }
  }

  Future<void> _getPoisAroundRoute(String langCode) async {
    try {
      debugPrint('🔍 Cargando POIs alrededor de la ruta: ${widget.routeId}, idioma: $langCode');
      final poisAround = await get_pois_around_a_route(widget.routeId, langCode);
      debugPrint('✅ POIs alrededor cargados: ${poisAround.length} POIs');
      if (mounted) {
        setState(() {
          _poisAroundRoute = poisAround;
          _poisAroundLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar los POIs alrededor de la ruta: $e');
      if (mounted) {
        setState(() {
          _poisAroundLoaded = true;
        });
      }
    }
  }

  Future<void> _loadElevationData() async {
    try {
      debugPrint('🏔️ Cargando datos de elevación para la ruta: ${widget.routeId}');
      final elevationData = await fetchRouteElevationData(widget.routeId);
      
      if (elevationData.isNotEmpty && mounted) {
        final points = elevationData.map((coords) => ElevationPoint.fromList(coords)).toList();
        
        setState(() {
          _elevationPoints = points;
          _elevationDataLoaded = true;
        });
        
        debugPrint('✅ Datos de elevación cargados: ${points.length} puntos');
      } else {
        debugPrint('⚠️ No se encontraron datos de elevación');
        if (mounted) {
          setState(() {
            _elevationDataLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error al cargar datos de elevación: $e');
      if (mounted) {
        setState(() {
          _elevationDataLoaded = true;
        });
      }
    }
  }

  List<List<LatLng>> get _displayedRoute {
    // Por defecto, mostrar toda la ruta
    if (_showFullRoute || _interestPoints.isEmpty || _routeCoordinates.isEmpty) {
      return _routeCoordinates;
    }
    List<LatLng> allPoints = _routeCoordinates.expand((s) => s).toList();
    LatLng startPoi = LatLng(
      widget.pois.first['latitude'],
      widget.pois.first['longitude'],
    );
    LatLng endPoi = LatLng(
      widget.pois.last['latitude'],
      widget.pois.last['longitude'],
    );
    bool adding = false;
    List<LatLng> displayedRoute = [];
    for (var point in allPoints) {
      if (!adding && _distance.as(LengthUnit.Meter, point, startPoi) < 500) {
        adding = true;
      }
      if (adding) {
        displayedRoute.add(point);
      }
      if (adding && _distance.as(LengthUnit.Meter, point, endPoi) < 500) {
        break;
      }
    }
    return [displayedRoute];
  }

  List get _displayedPOIs {
    List displayedPOIs = [];
    
    print('🗺️  Calculando POIs a mostrar...');
    print('   - _showFullRoute: $_showFullRoute');
    print('   - _interestPoints: ${_interestPoints.length}');
    print('   - _routeCoordinates: ${_routeCoordinates.length}');
    print('   - _showPoisAround: $_showPoisAround');
    print('   - _poisAroundRoute: ${_poisAroundRoute.length}');
    print('   - widget.pois (POIs de etapa): ${widget.pois.length}');
    
    // Primero agregar los POIs de la etapa (circulitos de la ruta)
    displayedPOIs.addAll(widget.pois);
    print('   ✅ Agregando POIs de etapa: ${widget.pois.length}');
    
    // Agregar los POIs originales (otros POIs de la ruta completa)
    if (_showFullRoute || _interestPoints.isEmpty || _routeCoordinates.isEmpty) {
      displayedPOIs.addAll(_interestPoints);
      print('   ✅ Agregando todos los POIs originales: ${_interestPoints.length}');
    } else {
      for (var poi in _interestPoints) {
        LatLng poiLatLng = LatLng(poi['latitude'], poi['longitude']);
        for (var routePoi in widget.pois) {
          LatLng routePoiLatLng = LatLng(
            routePoi['latitude'],
            routePoi['longitude'],
          );
          if (_distance.as(LengthUnit.Meter, poiLatLng, routePoiLatLng) < 1000) {
            displayedPOIs.add(poi);
            break;
          }
        }
      }
    }
    
    // Agregar los POIs alrededor de la ruta si el usuario los activó
    if (_showPoisAround && _poisAroundRoute.isNotEmpty) {
      print('   📍 Agregando POIs alrededor...');
      Set<String> existingPois = {};
      for (var poi in displayedPOIs) {
        existingPois.add('${poi['latitude']}_${poi['longitude']}');
      }
      
      for (var poi in _poisAroundRoute) {
        String poiKey = '${poi['latitude']}_${poi['longitude']}';
        if (!existingPois.contains(poiKey)) {
          // Aplicar el mismo filtro de distancia a los POIs alrededor
          if (_showFullRoute || _routeCoordinates.isEmpty) {
            // Si está en modo ruta completa, mostrar todos los POIs alrededor
            displayedPOIs.add(poi);
          } else {
            // Si está en modo ruta pequeña, filtrar por proximidad a widget.pois
            LatLng poiLatLng = LatLng(poi['latitude'], poi['longitude']);
            for (var routePoi in widget.pois) {
              LatLng routePoiLatLng = LatLng(
                routePoi['latitude'],
                routePoi['longitude'],
              );
              if (_distance.as(LengthUnit.Meter, poiLatLng, routePoiLatLng) < 1000) {
                displayedPOIs.add(poi);
                break;
              }
            }
          }
        }
      }
    }
    
    print('   ✅ Total POIs a mostrar: ${displayedPOIs.length}');
    return displayedPOIs;
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loading mientras se carga la ruta
    if (_isLoadingRoute) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                Provider.of<LocaleProvider>(context, listen: false)
                    .translate('loading_route'),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    // Usar la ubicación actual si está disponible, sino usar el primer POI
    LatLng displayPosition = _currentPosition;
    if (_currentPosition.latitude == 0 && _currentPosition.longitude == 0 && widget.pois.isNotEmpty) {
      displayPosition = LatLng(widget.pois.first['latitude'], widget.pois.first['longitude']);
    }
    
    return Scaffold(
      body: Stack(
        children: [
          CustomMap(
            currentPosition: displayPosition,
            mapController: _mapController,
            routes: [
              {
                'coordinates': _displayedRoute.expand((segment) => segment).toList(),
              }
            ],
            interestPoints: _displayedPOIs,
            routeCoordinates: _displayedRoute,
            walkingRoute: _walkingRoute,
            isAllRoutes: false,
            elevationPoints: _elevationPoints,
            useElevationColors: _useElevationColors && _elevationPoints.isNotEmpty,
          ),
          // Leyenda de colores de elevación
          if (_useElevationColors && _elevationPoints.isNotEmpty)
            const MapElevationLegend(),

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
              isRouteTrimmed: !_showFullRoute,
              onLocatePressed: () {
                _mapController.move(
                  LatLng(
                    _currentPosition.latitude,
                    _currentPosition.longitude,
                  ),
                  15,
                );
              },
              onToggleRoute: () {
                setState(() {
                  _showFullRoute = !_showFullRoute;
                });
              },
              onTogglePoisAround: () {
                setState(() {
                  _showPoisAround = !_showPoisAround;
                });
              },
              poisAroundLoaded: _poisAroundLoaded,
              showPoisAround: _showPoisAround,
              // Elevation controls - colores siempre activados por defecto
              elevationDataAvailable: _elevationDataLoaded && _elevationPoints.isNotEmpty,
              // elevationColorsEnabled: _useElevationColors,
              // onToggleElevationColors: () {
              //   setState(() {
              //     _useElevationColors = !_useElevationColors;
              //   });
              // },
              onShowRouteInfo: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => RouteInfoBottomSheet(
                    routeName: widget.routeName,
                    elevationPoints: _elevationPoints,
                  ),
                );
              },
            ),
          ),
            ],
          ),
    );
  }
}
