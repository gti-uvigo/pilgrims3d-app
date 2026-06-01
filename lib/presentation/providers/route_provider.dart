import 'package:flutter/material.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;

/// Gestiona el estado de la pantalla principal, incluyendo la carga de rutas.
class RouteProvider with ChangeNotifier {

  RouteProvider() {
    fetchRouteTypes();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _error = '';
  String get error => _error;

  List<dynamic> _routeTypes = [];
  List<dynamic> get routeTypes => _routeTypes;

  Future<void> fetchRouteTypes() async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      _routeTypes = await api.getRouteTypes();
    } catch (e) {
      _error = 'Error al cargar las rutas: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Aquí podrías añadir más lógica, como el manejo de las pestañas, filtros, etc.
}
