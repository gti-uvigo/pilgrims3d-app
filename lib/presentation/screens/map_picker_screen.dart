import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pilgrims_3d/core/config/theme.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:provider/provider.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapController _mapController;
  late LatLng _selectedLocation;
  late LatLng _initialLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    if (widget.initialLat != null && widget.initialLon != null) {
      _initialLocation = LatLng(widget.initialLat!, widget.initialLon!);
    } else {
      // Centro por defecto (Galicia, España)
      _initialLocation = LatLng(42.5, -8.0);
    }
    
    _selectedLocation = _initialLocation;
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await determinePosition();
      final newLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = newLocation;
      });
      
      _mapController.move(newLocation, 16);
    } catch (e) {
      final localeProvider = context.read<LocaleProvider>();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localeProvider.translate('error_getting_location')}: $e'),
          backgroundColor: AppTheme.accentBrown,
        ),
      );
    }
  }

  void _confirmLocation() {
    Navigator.of(context).pop({
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.translate('select_location')),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialLocation,
              initialZoom: widget.initialLat != null ? 18 : 13,
              onTap: (tapPosition, latLng) {
                setState(() {
                  _selectedLocation = latLng;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'pilgrims_3d_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Botón para ir a ubicación actual
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              tooltip: localeProvider.translate('use_current_location'),
              child: const Icon(Icons.my_location),
            ),
          ),
          // Barra de información inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${localeProvider.translate('latitude_label')}: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkGray),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${localeProvider.translate('longitude_label')}: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkGray),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      onPressed: _confirmLocation,
                      icon: const Icon(Icons.check),
                      label: Text(localeProvider.translate('confirm')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
