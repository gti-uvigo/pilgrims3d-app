import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pilgrims_3d/presentation/widgets/map/custom_map.dart';
import 'package:pilgrims_3d/presentation/widgets/map/map_floating_buttons.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;

class AllRoutesMapScreen extends StatefulWidget {
  final String routeType;
  final String languageId;

  const AllRoutesMapScreen({
    super.key,
    required this.routeType,
    required this.languageId,
  });

  @override
  State<AllRoutesMapScreen> createState() => _AllRoutesMapScreenState();
}

class _AllRoutesMapScreenState extends State<AllRoutesMapScreen> {
  final MapController _mapController = MapController();
  bool _isExpanded = false;
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _routes = [];

  final List<Color> _routeColors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.brown, Colors.cyan, Colors.indigo, Colors.lime, Colors.pink, Colors.amber, Colors.deepOrange, Colors.deepPurple, Colors.lightBlue, Colors.lightGreen, Colors.yellow, Colors.grey, Colors.blueGrey, Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        Position pos = await _determinePosition();
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      } catch (e) {
        print("Error al obtener la ubicación: $e");
      }
      await _loadRoutes();
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está deshabilitado.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos de ubicación están denegados permanentemente.');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _loadRoutes() async {
    try {
      final response = await api.getAllRoutesByRouteType(widget.routeType, widget.languageId);
      final List routes = response;
      List<Map<String, dynamic>> parsedRoutes = routes.asMap().entries.map((entry) {
        final index = entry.key;
        final r = entry.value;
        List<LatLng> coords = (r["route"] as List)
            .map((pair) => LatLng(pair[1], pair[0]))
            .toList();
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
      });
    } catch (e) {
      print('Error al cargar las rutas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _routes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CustomMap(
                  currentPosition: widget.routeType != "50da0d69-3647-4897-9dcc-2ed9820e1648"
                      ? LatLng(42.88064, -8.54439)
                      : LatLng(41.89022, 12.49228),
                  mapController: _mapController,
                  interestPoints: [],
                  routes: _routes,
                  routeCoordinates: [],
                  walkingRoute: [],
                  isAllRoutes: true,
                  onMapReady: () {},
                ),
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
                        _mapController.move(_currentPosition!, 15);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
