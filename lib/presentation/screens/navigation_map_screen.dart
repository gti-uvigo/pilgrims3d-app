import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'dart:math' as math;
import 'dart:async';

/// 🗺️ PANTALLA DE NAVEGACIÓN EN MODO GPS (tipo Google Maps)
/// Permite navegar desde tu ubicación actual a un destino específico
/// con visualización 3D, brújula y rotación automática según la dirección del dispositivo.
///
/// Los parámetros requeridos son:
/// - destinationLatitude: Latitud del destino
/// - destinationLongitude: Longitud del destino
/// - destinationName: Nombre del destino (opcional)
///
/// Características:
/// - 🧭 Brújula que rota con el sensor del teléfono
/// - 📍 Mapa orientado según la dirección de movimiento
/// - 🎯 Línea recta al destino
/// - � Distancia actualizada en tiempo real
class NavigationMapScreen extends StatefulWidget {
  final double destinationLatitude;
  final double destinationLongitude;
  final String? destinationName;

  const NavigationMapScreen({
    super.key,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.destinationName,
  });

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  LatLng _currentPosition = LatLng(0, 0);
  late LatLng _destinationPosition;
  List<List<LatLng>> _navigationRoute = [];
  final MapController _mapController = MapController();
  bool _isLoading = true;
  String _errorMessage = '';
  final Distance _distance = Distance();
  double _heading = 0.0; // Brújula del dispositivo
  double _bearing = 0.0; // Ángulo hacia el destino
  DateTime? _lastRouteUpdate;
  bool _isRouteUpdating = false;

  // StreamSubscriptions para limpieza
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _destinationPosition = LatLng(
      widget.destinationLatitude,
      widget.destinationLongitude,
    );
    _initializeNavigation();
    _startCompassListener();
    // Esperar a que el frame se renderice antes de iniciar los updates de ubicación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationUpdates();
    });
  }

  /// Escucha los cambios de ubicación y mantiene el mapa centrado en la parte inferior
  void _startLocationUpdates() {
    if (!kIsWeb) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10, // Actualizar cada 10 metros
        ),
      ).listen((Position position) {
        final previousPosition = _currentPosition;
        final newPosition = LatLng(position.latitude, position.longitude);

        // Solo actualizar si hay cambio significativo (optimización)
        final distanceChanged =
            _distance.as(LengthUnit.Meter, _currentPosition, newPosition) > 5;

        if (mounted && distanceChanged) {
          setState(() {
            _currentPosition = newPosition;
          });

          // Solo mover el mapa si el controller está listo
          try {
            _mapController.move(_currentPosition, 20);
          } catch (e) {
            debugPrint('⚠️ Error al mover el mapa: $e');
          }

          _maybeUpdateRoute(previousPosition, newPosition);
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  /// Inicia el listener de la brújula para obtener la orientación del dispositivo
  void _startCompassListener() {
    if (!kIsWeb) {
      _compassSubscription = FlutterCompass.events?.listen((event) {
        final newHeading = event.heading ?? 0.0;

        // Solo actualizar si hay cambio significativo (throttling)
        if (mounted && (newHeading - _heading).abs() > 2) {
          setState(() {
            _heading = newHeading;
          });
        }
      });
    }
  }

  /// Calcula el ángulo (bearing) desde la ubicación actual al destino
  double _calculateBearing(LatLng from, LatLng to) {
    const double toRad = math.pi / 180;
    const double toDeg = 180 / math.pi;

    double lat1 = from.latitude * toRad;
    double lat2 = to.latitude * toRad;
    double dLng = (to.longitude - from.longitude) * toRad;

    double bearing = math.atan2(
      math.sin(dLng) * math.cos(lat2),
      math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(dLng),
    );

    return (bearing * toDeg + 360) % 360;
  }

  /// Inicializa la navegación obteniendo ubicación actual y calculando ruta
  Future<void> _initializeNavigation() async {
    try {
      // Obtener ubicación actual
      await _getCurrentLocation();

      // Calcular ruta de navegación
      if (_currentPosition.latitude != 0 && _currentPosition.longitude != 0) {
        await _calculateNavigationRoute();
      }

      // Actualizar ubicación en el backend
      if (!kIsWeb) {
        await updateUserCoords(
          _currentPosition.latitude,
          _currentPosition.longitude,
        ).catchError((e) {
          print('⚠️ Error actualizando ubicación en backend: $e');
        });
      }
    } catch (e) {
      print('❌ Error al inicializar navegación: $e');
      setState(() {
        _errorMessage = 'Error al obtener tu ubicación: $e';
        _isLoading = false;
      });
    }
  }

  /// Obtiene la ubicación actual del usuario
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await determinePosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      print('✅ Ubicación actual obtenida: $_currentPosition');
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
      rethrow;
    }
  }

  /// Calcula la ruta de navegación desde ubicación actual al destino
  Future<void> _calculateNavigationRoute() async {
    try {
      print(
        '📍 Calculando ruta desde $_currentPosition a $_destinationPosition',
      );

      // Obtener coordenadas de la ruta usando two_points_route
      List<LatLng> routePoints = [];
      try {
        routePoints = await two_points_route(
          _currentPosition.latitude,
          _currentPosition.longitude,
          _destinationPosition.latitude,
          _destinationPosition.longitude,
        );
      } catch (e) {
        print('⚠️ Error al obtener ruta del servidor: $e');
        // Continuar con ruta vacía
        routePoints = [];
      }

      setState(() {
        // Si tenemos puntos de la ruta, los organizamos en segmentos
        if (routePoints.isNotEmpty) {
          _navigationRoute = [routePoints];
        } else {
          // Si no hay ruta, crear una línea simple entre los dos puntos
          _navigationRoute = [
            [_currentPosition, _destinationPosition],
          ];
        }
        _isLoading = false;
      });

      print('✅ Ruta calculada: ${routePoints.length} puntos');
    } catch (e) {
      print('⚠️ Error al calcular ruta detallada: $e');
      // Crear ruta simple si no se puede obtener la detallada
      setState(() {
        _navigationRoute = [
          [_currentPosition, _destinationPosition],
        ];
        _isLoading = false;
      });
    }
  }

  void _maybeUpdateRoute(LatLng previousPosition, LatLng newPosition) {
    if (_isRouteUpdating) {
      return;
    }

    final movedMeters = _distance.as(
      LengthUnit.Meter,
      previousPosition,
      newPosition,
    );

    final lastUpdate = _lastRouteUpdate;
    final now = DateTime.now();
    final elapsedSeconds =
        lastUpdate == null
            ? double.infinity
            : now.difference(lastUpdate).inSeconds.toDouble();

    if (movedMeters < 20 || elapsedSeconds < 20) {
      return;
    }

    _isRouteUpdating = true;
    _lastRouteUpdate = now;

    _calculateNavigationRoute().whenComplete(() {
      _isRouteUpdating = false;
    });
  }

  /// Calcula la distancia al destino
  String _getDistanceToDestination() {
    double distanceInMeters = _distance.as(
      LengthUnit.Meter,
      _currentPosition,
      _destinationPosition,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    _bearing = _calculateBearing(_currentPosition, _destinationPosition);

    return Scaffold(
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Preparando navegación...'),
                  ],
                ),
              )
              : _errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        _initializeNavigation();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  // 🗺️ MAPA CON NORTE SIEMPRE HACIA ARRIBA
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 20,
                      minZoom: 15,
                      maxZoom: 20,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.pilgrimsapp',
                      ),
                      // Línea de ruta
                      PolylineLayer(
                        polylines: [
                          if (_navigationRoute.isNotEmpty &&
                              _navigationRoute[0].isNotEmpty)
                            Polyline(
                              points: _navigationRoute[0],
                              color: Colors.blue.withOpacity(0.7),
                              strokeWidth: 6,
                            ),
                          if (_navigationRoute.isEmpty ||
                              _navigationRoute[0].length <= 2)
                            Polyline(
                              points: [_currentPosition, _destinationPosition],
                              color: Colors.red.withOpacity(0.3),
                              strokeWidth: 3,
                            ),
                        ],
                      ),
                      // Marcadores
                      MarkerLayer(
                        markers: [
                          // Ubicación actual con dirección
                          Marker(
                            point: _currentPosition,
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Círculo de fondo
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                // Icono de persona que rota con la dirección
                                Transform.rotate(
                                  angle: _heading * math.pi / 180,
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Destino
                          Marker(
                            point: _destinationPosition,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flag,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // INFORMACIÓN DE NAVEGACIÓN (Centro Arriba)
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Distancia
                          Text(
                            _getDistanceToDestination(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'al destino',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // BRÚJULA (Arriba a la derecha)
                  Positioned(
                    top: 120,
                    right: 16,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Círculo de fondo
                          CustomPaint(
                            size: const Size(80, 80),
                            painter: _CompassPainter(_heading, _bearing),
                          ),
                          // Indicador central
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // BOTONES FLOTANTES (Inferior Derecha)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: 'zoomIn',
                          mini: true,
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom + 1,
                            );
                          },
                          tooltip: 'Zoom +',
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: 'zoomOut',
                          mini: true,
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            _mapController.move(
                              _mapController.camera.center,
                              (_mapController.camera.zoom - 1).clamp(
                                15.0,
                                20.0,
                              ),
                            );
                          },
                          tooltip: 'Zoom -',
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: 'recenter',
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            _mapController.move(_currentPosition, 20);
                          },
                          tooltip: 'Centrar en mi ubicación',
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

/// 🧭 CustomPainter para dibujar la brújula
class _CompassPainter extends CustomPainter {
  final double heading; // Ángulo del dispositivo (brújula)
  final double bearing; // Ángulo hacia el destino

  _CompassPainter(this.heading, this.bearing);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Dibujar círculo de fondo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Dibujar borde del círculo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rotar canvas según la brújula
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // Dibujar norte (N)
    final northTextPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.red,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    northTextPainter.layout();
    northTextPainter.paint(
      canvas,
      Offset(center.dx - northTextPainter.width / 2, center.dy - radius + 6),
    );

    // Línea hacia el norte
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 8),
      Offset(center.dx, center.dy - 8),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2,
    );

    // Invertir rotación para dibujar el bearing
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // Rotar según el bearing
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bearing * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // Flecha azul hacia el destino
    final arrowPaint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // Punta de flecha
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 12),
      Offset(center.dx, center.dy - 4),
      arrowPaint,
    );

    // Ala izquierda de la flecha
    canvas.drawLine(
      Offset(center.dx - 4, center.dy - 12),
      Offset(center.dx, center.dy - 4),
      arrowPaint,
    );

    // Ala derecha de la flecha
    canvas.drawLine(
      Offset(center.dx + 4, center.dy - 12),
      Offset(center.dx, center.dy - 4),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) {
    return oldDelegate.heading != heading || oldDelegate.bearing != bearing;
  }
}
