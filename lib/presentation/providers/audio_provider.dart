import 'package:flutter/material.dart';
import '../../data/models/audio.dart';
import '../../services/api/api_service.dart' as api;

/// Provider para gestionar el estado de los audios
class AudioProvider extends ChangeNotifier {
  List<AudioModel> _audios = [];
  bool _isLoading = false;
  String _error = '';
  
  // Mapa para almacenar información de rutas por routeId
  final Map<String, String> _routeNames = {};

  List<AudioModel> get audios => _audios;
  bool get isLoading => _isLoading;
  String get error => _error;

  /// Obtiene el nombre de la ruta por su ID
  String getRouteName(String routeId) {
    return _routeNames[routeId] ?? 'Ruta desconocida';
  }

  /// Carga todos los audios disponibles
  Future<void> loadAudios() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final List<Map<String, dynamic>> response = await api.getAllAudios();
      
      _audios = response.map((json) => AudioModel.fromJson(json)).toList();
      
      // Ordenar por fecha de subida (más recientes primero)
      _audios.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      
      print('✅ ${_audios.length} audios cargados exitosamente');
    } catch (e) {
      _error = 'Error al cargar audios: $e';
      print('❌ Error al cargar audios: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recarga los audios (útil para pull-to-refresh)
  Future<void> refreshAudios() async {
    await loadAudios();
  }

  /// Limpia el estado del provider
  void clear() {
    _audios = [];
    _error = '';
    _isLoading = false;
    _routeNames.clear();
    notifyListeners();
  }

  /// Agrega o actualiza el nombre de una ruta
  void setRouteName(String routeId, String routeName) {
    _routeNames[routeId] = routeName;
    notifyListeners();
  }

  /// Busca audios por título o nombre de archivo
  List<AudioModel> searchAudios(String query) {
    if (query.isEmpty) return _audios;
    
    final lowerQuery = query.toLowerCase();
    return _audios.where((audio) {
      return audio.metadata.title.toLowerCase().contains(lowerQuery) ||
             audio.filename.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Obtiene audios filtrados por ID de ruta
  List<AudioModel> getAudiosByRouteId(String routeId) {
    return _audios.where((audio) => audio.metadata.routeId == routeId).toList();
  }
}
