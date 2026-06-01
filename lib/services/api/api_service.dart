import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Necesario para SocketException

import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pilgrims_3d/core/utils/crypto.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

// Imports condicionales para servicios offline
import 'package:pilgrims_3d/services/offline/offline_storage_service_stub.dart'
    if (dart.library.io) 'package:pilgrims_3d/services/offline/offline_storage_service.dart';
import 'package:pilgrims_3d/services/offline/image_cache_service_stub.dart'
    if (dart.library.io) 'package:pilgrims_3d/services/offline/image_cache_service.dart';

final OfflineStorageService _offlineStorage = OfflineStorageService();
final ImageCacheService _imageCache = ImageCacheService();

// Variable global para controlar si se debe usar solo caché offline
bool _offlineMode = false;

// Variable para controlar si se debe evitar usar caché en online (fuerza refresh)
bool _forceRefreshMode = false;

void setOfflineMode(bool enabled) {
  _offlineMode = enabled;
}

void setForceRefreshMode(bool enabled) {
  _forceRefreshMode = enabled;
  print('🔄 Modo force refresh: ${enabled ? "ACTIVADO" : "DESACTIVADO"}');
}

bool get isForceRefreshMode => _forceRefreshMode;
bool get isOfflineMode => _offlineMode;

// Helpers para manejar null en web
Future<dynamic> _getCachedApiResponse(
  String cacheKey,
  Map<String, dynamic> params,
) async {
  return await _offlineStorage.getCachedApiResponse(cacheKey, params);
}

Future<void> _cacheApiResponse(
  String cacheKey,
  Map<String, dynamic> params,
  dynamic data,
) async {
  await _offlineStorage.cacheApiResponse(cacheKey, params, data);
}

Future<File?> _getCachedImage(String imageId) async {
  return await _imageCache.getCachedImage(imageId);
}

void _downloadAndCacheImage(String url, String imageId) {
  _imageCache.downloadAndCacheImage(url, imageId);
}

/// Determina si se debe usar caché para una petición
/// - En modo offline: siempre usar caché
/// - En modo online: usar caché solo si no está en force refresh mode
bool _shouldUseCache() {
  if (_offlineMode) return true; // Offline: siempre usar caché
  return !_forceRefreshMode; // Online: usar caché solo si no está en force refresh
}

/// Determina si se debe hacer petición al servidor
/// - En modo offline: nunca hacer petición
/// - En modo online: siempre hacer petición (independientemente del caché)
bool _shouldMakeRequest() {
  return !_offlineMode; // Solo hacer petición si no estamos offline
}

// --- Función Auxiliar para Peticiones con Reintentos ---

/// Realiza una petición HTTP con una lógica de reintentos y timeout.
///
/// [requestFunction] es la función que ejecuta la petición (ej. http.get, http.post).
/// [retries] es el número máximo de intentos.
/// [timeoutDuration] es el tiempo de espera máximo para cada intento.
Future<http.Response?> makeRequestWithRetry(
  Future<http.Response> Function() requestFunction, {
  int retries = 3,
  Duration timeoutDuration = const Duration(seconds: 8),
}) async {
  if (_offlineMode) {
    print('Modo offline activo: evitando petición HTTP');
    return null;
  }
  final connectivityResult = await Connectivity().checkConnectivity();
  final hasConnection = connectivityResult != ConnectivityResult.none;
  if (!hasConnection) {
    setOfflineMode(true);
    print('Sin conexión: evitando petición HTTP');
    return null;
  }
  if (!kIsWeb) {
    try {
      final host = Uri.parse(baseUrl).host;
      final lookup = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 2));
      if (lookup.isEmpty) {
        setOfflineMode(true);
        print('Sin resolución DNS: evitando petición HTTP');
        return null;
      }
    } on SocketException {
      setOfflineMode(true);
      print('Sin resolución DNS: evitando petición HTTP');
      return null;
    } on TimeoutException {
      setOfflineMode(true);
      print('Timeout DNS: evitando petición HTTP');
      return null;
    }
  }
  for (int i = 0; i < retries; i++) {
    try {
      final response = await requestFunction().timeout(timeoutDuration);
      return response;
    } on TimeoutException {
      print('Intento ${i + 1} fallido por timeout. Reintentando...');
      if (i == retries - 1) {
        print('Todos los intentos de reintento fallaron por timeout.');
        return null;
      }
    } on SocketException catch (e) {
      print('Intento ${i + 1} fallido por error de red: $e. Reintentando...');
      setOfflineMode(true);
      print('Todos los intentos de reintento fallaron por error de red.');
      return null;
    } catch (e) {
      print('Ocurrió un error inesperado durante la petición: $e');
      return null;
    }
  }
  return null;
}

// --- Función Auxiliar para Asegurar Credenciales ---

/// Asegura que el idToken esté disponible, obteniéndolo del usuario actual si es necesario.
/// Retorna true si se pudo obtener, false en caso contrario.
Future<bool> _ensureIdToken() async {
  if (idToken.isEmpty) {
    // En background service, Firebase puede no estar disponible
    // Intentar obtener el token de SharedPreferences primero
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('idToken');
      if (savedToken != null && savedToken.isNotEmpty) {
        idToken = savedToken;
        print('✅ ID Token obtenido de SharedPreferences');
        return true;
      }
    } catch (e) {
      print('⚠️ Error obteniendo token de SharedPreferences: $e');
    }

    // Si no hay token guardado, intentar con Firebase
    try {
      User? user = FirebaseAuth.instance.currentUser;
      print('Usuario actual: $user');
      if (user != null && user.email != null) {
        idToken = (await getEmailSha256(user.email)) ?? "";
        if (idToken.isEmpty) {
          print('No se pudo generar el ID Token del usuario.');
          return false;
        }
      } else {
        print('No se pudo obtener el ID Token del usuario.');
        return false;
      }
    } catch (e) {
      print('⚠️ Error con Firebase Auth: $e');
      return false;
    }
  }
  return true;
}

/// Asegura que el email esté disponible, obteniéndolo del usuario actual si es necesario.
/// Retorna true si se pudo obtener, false en caso contrario.
Future<bool> _ensureEmail() async {
  if (email.isEmpty) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      email = user.email!;
    } else {
      print('No se pudo obtener el email del usuario.');
      return false;
    }
  }
  return true;
}

// --- Funciones de la API Refactorizadas ---

Future<List> getDaysInformation(String routeId, String languageId) async {
  print(
    'Obteniendo información de los días para la ruta $routeId y el idioma $languageId',
  );

  // Definir los parámetros del body primero
  final body = {
    "route_id": routeId,
    "language_id": languageId,
    "user_id": idToken,
  };
  final cacheParams = {"route_id": routeId, "language_id": languageId};

  final cacheKey = 'route_stages';

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, cacheParams);
    if (cachedData != null) {
      print('✅ Devolviendo días desde caché');
      return cachedData as List;
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    print('⚠️ Modo offline: no hay datos en caché para esta ruta');
    return [];
  }

  print('🌐 Obteniendo días del servidor (nueva petición)');

  String uri = '$baseUrl/route_stages';

  print('Realizando petición para obtener días con body: $body');

  final url = Uri.parse(uri);

  final response = await makeRequestWithRetry(
    () => http.post(
      url,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];
    print("Response de los dias : $data");

    // Siempre guardar en caché cuando obtenemos datos frescos
    await _cacheApiResponse(cacheKey, cacheParams, data);
    print('✅ Días obtenidos del servidor y guardados en caché');

    return data;
  } else {
    print('❌ Falló la petición de días - intentando caché como fallback');

    // Como fallback, intentar caché aunque estuviéramos en force refresh
    final cachedData = await _getCachedApiResponse(cacheKey, cacheParams);
    if (cachedData != null) {
      print('✅ Usando días desde caché como fallback');
      return cachedData as List;
    }

    print('❌ No hay datos de días disponibles');
    return [];
  }
}

Future<List> getCardInformation(
  String routeId,
  String subtype,
  String languageId,
) async {
  print(
    'Obteniendo información de las tarjetas para la ruta $routeId, subtipo $subtype y el idioma $languageId',
  );

  final cacheKey = 'routes';
  final params = {
    "route_type": routeId,
    "type": subtype,
    "language_id": languageId,
  };

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, params);
    if (cachedData != null) {
      print('✅ Devolviendo tarjetas desde caché');
      return cachedData as List;
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    print('⚠️ Modo offline: no hay datos en caché');
    return [];
  }

  print('🌐 Obteniendo tarjetas del servidor (nueva petición)');

  final url = Uri.parse('$baseUrl/routes');

  final response = await makeRequestWithRetry(
    () => http.post(
      url,
      body: jsonEncode(params),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];

    // Siempre guardar en caché cuando obtenemos datos frescos
    await _cacheApiResponse(cacheKey, params, data);
    print('✅ Tarjetas obtenidas del servidor y guardadas en caché');

    return data;
  } else {
    print('❌ Falló la petición de tarjetas - intentando caché como fallback');

    // Como fallback, intentar caché aunque estuviéramos en force refresh
    final cachedData = await _getCachedApiResponse(cacheKey, params);
    if (cachedData != null) {
      print('✅ Usando tarjetas desde caché como fallback');
      return cachedData as List;
    }

    print('❌ No hay datos de tarjetas disponibles');
    return [];
  }
}

Future<Map<String, List<List<LatLng>>>> fetchRouteCoordinates(
  String routeId,
  LatLng actualPosition,
  LatLng destinationPosition,
) async {
  print(
    'Obteniendo coordenadas de la ruta $routeId desde la posición $actualPosition',
  );

  // Intentar obtener desde caché primero
  final cacheKey = 'route_locations/$routeId';
  final params = {
    "start_lat": actualPosition.latitude.toString(),
    "start_lng": actualPosition.longitude.toString(),
    "end_lat": destinationPosition.latitude.toString(),
    "end_lng": destinationPosition.longitude.toString(),
  };

  final cachedData = await _getCachedApiResponse(cacheKey, params);

  if (cachedData != null) {
    print('Devolviendo coordenadas de ruta desde caché offline');
    List<List<LatLng>> coordinates = [];
    List<List<LatLng>> walking = [];

    final List<LatLng> coordinate =
        (cachedData['all_route'] as List)
            .map<LatLng>((pair) => LatLng(pair[1], pair[0]))
            .toList();
    coordinates.add(coordinate);

    if (cachedData['route_to_start'] != null &&
        (cachedData['route_to_start'] as List).isNotEmpty) {
      final List<LatLng> walk =
          (cachedData['route_to_start'] as List)
              .map<LatLng>((pair) => LatLng(pair[1], pair[0]))
              .toList();
      walking.add(walk);
    }

    return {"all_coordinates": coordinates, "walking": walking};
  }

  // Si estamos en modo offline y no hay caché, retornar vacío
  if (_offlineMode) {
    print('Modo offline: no hay datos en caché para coordenadas de ruta');
    return {};
  }

  String uri = '$baseUrl/route_locations/$routeId';
  final url = Uri.parse(uri);

  final response = await makeRequestWithRetry(
    () => http.post(
      url,
      body: jsonEncode({
        "start_points": [actualPosition.latitude, actualPosition.longitude],
        "end_points": [
          destinationPosition.latitude,
          destinationPosition.longitude,
        ],
      }),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final route = jsonDecode(response.body)["data"];

    // Guardar en caché
    await _cacheApiResponse(cacheKey, params, route);

    List<List<LatLng>> coordinates = [];
    List<List<LatLng>> walking = [];

    final List<LatLng> coordinate =
        (route['all_route'] as List)
            .map<LatLng>((pair) => LatLng(pair[1], pair[0]))
            .toList();
    coordinates.add(coordinate);

    if (route['route_to_start'] != null &&
        (route['route_to_start'] as List).isNotEmpty) {
      final List<LatLng> walk =
          (route['route_to_start'] as List)
              .map<LatLng>((pair) => LatLng(pair[1], pair[0]))
              .toList();
      walking.add(walk);
    }

    return {"all_coordinates": coordinates, "walking": walking};
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return {};
  }
}

/// Obtiene las coordenadas base de la ruta completa (solo all_route, sin navegación)
/// Útil para mostrar la ruta en el mapa sin calcular navegación desde ubicación del usuario
Future<List<List<LatLng>>> fetchBaseRouteCoordinates(String routeId) async {
  print('Obteniendo coordenadas base de la ruta $routeId');

  // Intentar obtener desde caché primero
  final cacheKey = 'route_base_coordinates/$routeId';

  final cachedData = await _getCachedApiResponse(cacheKey, {});

  if (cachedData != null) {
    print('Devolviendo coordenadas base desde caché offline');
    final List<LatLng> coordinates =
        (cachedData as List)
            .map<LatLng>((pair) => LatLng(pair[1], pair[0]))
            .toList();
    return [coordinates];
  }

  // Si estamos en modo offline y no hay caché, retornar vacío
  if (_offlineMode) {
    print('Modo offline: no hay coordenadas base en caché para ruta $routeId');
    return [];
  }

  // Obtener primer y último punto de la ruta desde los POIs
  final pois = await fetchInterestPoints(
    routeId,
    'en',
  ); // Idioma no importa para coordenadas
  if (pois.isEmpty) {
    print('No hay POIs para obtener coordenadas de ruta');
    return [];
  }

  final firstPoi = pois.first;
  final lastPoi = pois.last;

  final startPos = LatLng(firstPoi['latitude'], firstPoi['longitude']);
  final endPos = LatLng(lastPoi['latitude'], lastPoi['longitude']);

  String uri = '$baseUrl/route_locations/$routeId';
  final url = Uri.parse(uri);

  final response = await makeRequestWithRetry(
    () => http.post(
      url,
      body: jsonEncode({
        "start_points": [startPos.latitude, startPos.longitude],
        "end_points": [endPos.latitude, endPos.longitude],
      }),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final route = jsonDecode(response.body)["data"];
    final allRoute = route['all_route'] as List;

    // Guardar en caché las coordenadas base (solo all_route)
    await _cacheApiResponse(cacheKey, {}, allRoute);

    final List<LatLng> coordinates =
        allRoute.map<LatLng>((pair) => LatLng(pair[1], pair[0])).toList();

    return [coordinates];
  } else {
    print('Falló la petición de coordenadas base tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

/// Obtiene las coordenadas de la ruta con datos de elevación
/// Retorna una lista de puntos [longitude, latitude, elevation]
Future<List<List<dynamic>>> fetchRouteElevationData(String routeId) async {
  print('Obteniendo datos de elevación de la ruta $routeId');

  // Intentar obtener desde caché primero
  final cacheKey = 'route_elevation_data/$routeId';

  final cachedData = await _getCachedApiResponse(cacheKey, {});

  if (cachedData != null) {
    print('Devolviendo datos de elevación desde caché offline');
    return (cachedData as List).map((item) => item as List<dynamic>).toList();
  }

  // Si estamos en modo offline y no hay caché, retornar vacío
  if (_offlineMode) {
    print(
      'Modo offline: no hay datos de elevación en caché para ruta $routeId',
    );
    return [];
  }

  // Obtener primer y último punto de la ruta desde los POIs
  final pois = await fetchInterestPoints(
    routeId,
    'en',
  ); // Idioma no importa para coordenadas
  if (pois.isEmpty) {
    print('No hay POIs para obtener coordenadas de ruta');
    return [];
  }

  final firstPoi = pois.first;
  final lastPoi = pois.last;

  final startPos = LatLng(firstPoi['latitude'], firstPoi['longitude']);
  final endPos = LatLng(lastPoi['latitude'], lastPoi['longitude']);

  String uri = '$baseUrl/route_locations/$routeId';
  final url = Uri.parse(uri);

  final response = await makeRequestWithRetry(
    () => http.post(
      url,
      body: jsonEncode({
        "start_points": [startPos.latitude, startPos.longitude],
        "end_points": [endPos.latitude, endPos.longitude],
      }),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final route = jsonDecode(response.body)["data"];
    final allRoute = route['all_route'] as List;

    // Guardar en caché los datos de elevación
    await _cacheApiResponse(cacheKey, {}, allRoute);

    return allRoute.map((item) => item as List<dynamic>).toList();
  } else {
    print('Falló la petición de datos de elevación tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<dynamic>> fetchInterestPoints(
  String routeId,
  String languageId,
) async {
  print(
    'Obteniendo puntos de interés para la ruta $routeId y el idioma $languageId',
  );

  final cacheKey = 'pois_by_route/$routeId';
  final params = {"language_id": languageId};

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, params);
    if (cachedData != null) {
      print('✅ Devolviendo POIs desde caché');
      return cachedData as List<dynamic>;
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    print('⚠️ Modo offline: no hay datos en caché para POIs');
    return [];
  }

  print('🌐 Obteniendo POIs del servidor (nueva petición)');

  final String url = "$baseUrl/pois_by_route/$routeId?language_id=$languageId";

  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];

    // Siempre guardar en caché cuando obtenemos datos frescos
    await _cacheApiResponse(cacheKey, params, data);
    print('✅ POIs obtenidos del servidor y guardados en caché');

    return data;
  } else {
    print('❌ Falló la petición de POIs - intentando caché como fallback');

    // Como fallback, intentar caché aunque estuviéramos en force refresh
    final cachedData = await _getCachedApiResponse(cacheKey, params);
    if (cachedData != null) {
      print('✅ Usando POIs desde caché como fallback');
      return cachedData as List<dynamic>;
    }

    print('❌ No hay datos de POIs disponibles');
    return [];
  }
}

Future<List<dynamic>> getLanguages() async {
  const String cacheKey = 'languages';

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, {});
    if (cachedData != null) {
      debugPrint('✅ Devolviendo idiomas desde caché');
      return cachedData as List<dynamic>;
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    debugPrint('⚠️ Modo offline: no hay datos en caché para idiomas');
    return [];
  }

  debugPrint('🌐 Obteniendo idiomas del servidor (nueva petición)');

  final String url = '$baseUrl/languages';
  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"] as List<dynamic>;

    // Siempre guardar en caché cuando obtenemos datos frescos
    await _cacheApiResponse(cacheKey, {}, data);
    debugPrint('✅ Idiomas obtenidos del servidor y guardados en caché');

    return data;
  } else {
    debugPrint(
      '❌ Falló la petición de idiomas - intentando caché como fallback',
    );

    // Como fallback, intentar caché aunque estuviéramos en force refresh
    final cachedData = await _getCachedApiResponse(cacheKey, {});
    if (cachedData != null) {
      debugPrint('✅ Usando idiomas desde caché como fallback');
      return cachedData as List<dynamic>;
    }

    debugPrint('❌ No hay datos de idiomas disponibles');
    return <dynamic>[];
  }
}

Future<List<dynamic>> getRouteTypes() async {
  const String cacheKey = 'route_types';

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, {});
    if (cachedData != null) {
      debugPrint('✅ Devolviendo tipos de ruta desde caché');
      return cachedData as List<dynamic>;
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    debugPrint('⚠️ Modo offline: no hay datos en caché para tipos de ruta');
    return [];
  }

  debugPrint('🌐 Obteniendo tipos de ruta del servidor (nueva petición)');

  final String url = "$baseUrl/route_types";
  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"] as List<dynamic>;

    // Siempre guardar en caché cuando obtenemos datos frescos
    await _cacheApiResponse(cacheKey, {}, data);
    debugPrint('✅ Tipos de ruta obtenidos del servidor y guardados en caché');

    return data;
  } else {
    debugPrint(
      '❌ Falló la petición de tipos de ruta - intentando caché como fallback',
    );

    // Como fallback, intentar caché aunque estuviéramos en force refresh
    final cachedData = await _getCachedApiResponse(cacheKey, {});
    if (cachedData != null) {
      debugPrint('✅ Usando tipos de ruta desde caché como fallback');
      return cachedData as List<dynamic>;
    }

    debugPrint('❌ No hay datos de tipos de ruta disponibles');
    return <dynamic>[];
  }
}

Future<Image> fetchImage(String imageId) async {
  print('Obteniendo imagen con id $imageId');

  // Intentar obtener desde caché local primero
  final cachedImage = await _getCachedImage(imageId);
  if (cachedImage != null) {
    print('Devolviendo imagen desde caché local');
    return Image.file(cachedImage);
  }

  // Si estamos en modo offline y no hay caché, usar imagen por defecto
  if (_offlineMode) {
    print('Modo offline: imagen no disponible en caché');
    return Image.asset('images/default_image.png');
  }

  final String url = "$baseUrl/images/$imageId";

  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    // Guardar en caché de manera asíncrona (no bloqueante)
    _downloadAndCacheImage(url, imageId);

    return Image.memory(response.bodyBytes);
  } else {
    print('Error al cargar la imagen. Se usará la imagen por defecto.');
    if (response != null) {
      print('Último estado: ${response.statusCode}');
    }
    return Image.asset('images/default_image.png'); // Imagen por defecto
  }
}

Future<Map<String, dynamic>?> fetchPoiDetail(
  String poiId,
  String languageId,
) async {
  debugPrint('Obteniendo detalle del POI $poiId en idioma $languageId');

  final cacheKey = 'poi/$poiId';
  final params = {"language_id": languageId};

  final cachedData = await _getCachedApiResponse(cacheKey, params);
  if (cachedData is Map<String, dynamic>) {
    return Map<String, dynamic>.from(cachedData);
  }

  if (_offlineMode) {
    debugPrint('Modo offline: no hay datos en caché para POI $poiId');
    return null;
  }

  final String url = "$baseUrl/poi/$poiId?language_id=$languageId";

  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final data = Map<String, dynamic>.from(
      jsonDecode(response.body)["data"] as Map,
    );

    await _cacheApiResponse(cacheKey, params, data);
    return data;
  }

  debugPrint('No se pudo cargar el detalle del POI $poiId');
  if (response != null) {
    debugPrint(
      'Último estado: ${response.statusCode}. Cuerpo: ${response.body}',
    );
  }
  return null;
}

Future<String> moreInfoPois(String poiId, String languageId) async {
  final detail = await fetchPoiDetail(poiId, languageId);

  if (detail != null) {
    return detail["description"]?.toString() ?? "No info";
  }

  if (_offlineMode) {
    return 'No disponible offline';
  }

  return "No info";
}

Future<List<dynamic>> getPoisTypes(String languageId) async {
  print('Obteniendo tipos de puntos de interés disponibles');
  const String cacheKey = 'pois_types';
  final params = {"language_id": languageId};

  final cachedData = await _getCachedApiResponse(cacheKey, params);

  if (cachedData != null) {
    print('Devolviendo tipos de POI desde caché offline');
    return cachedData as List<dynamic>;
  }

  if (_offlineMode) {
    print('Modo offline: no hay datos en caché para tipos de POI');
    return [];
  }

  final String url = "$baseUrl/pois_types/$languageId";

  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];

    await _cacheApiResponse(cacheKey, params, data);
    return data;
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<dynamic>> getAllRoutesByRouteType(
  String routeType,
  String languageId,
) async {
  print(
    'Obteniendo todas las rutas para el tipo $routeType y el idioma $languageId',
  );
  final String url = "$baseUrl/get_all_routes_by_route_type";

  final body = {"route_type": routeType, "language_id": languageId};

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    return jsonDecode(response.body)["data"];
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<void> registerUser() async {
  final String url = "$baseUrl/register_user";

  final body = {
    "email": email,
    "id_token": idToken,
    "fcm_token": notificationsToken,
  };


  final response = await http.post(
    Uri.parse(url),
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    print('Usuario registrado exitosamente.');
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
  }
}

Future<void> updateUserCoords(lat, long) async {
  print(
    'Actualizando coordenadas del usuario $idToken a lat: $lat, long: $long',
  );
  final String url = "$baseUrl/update_user";

  if (!await _ensureIdToken()) {
    return;
  }

  final body = {
    "id_token": idToken,
    "latitude": lat,
    "longitude": long,
    "timestamp": DateTime.now().toIso8601String(),
  };

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    print('Coordenadas actualizadas exitosamente.');
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
  }
}

// ignore: non_constant_identifier_names
Future<int> send_notification_sos() async {
  print('Enviando notificación SOS para el usuario $idToken');
  final String url = "$baseUrl/send_notification_sos";

  if (!await _ensureIdToken()) {
    return 2; // Error code
  }

  final body = {"id_token": idToken};

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  print("---------------____------->${response?.body}");

  if (response != null && response.statusCode == 200) {
    print('Notificación SOS enviada exitosamente.');
    return 0;
  } else if (response != null && response.statusCode == 445) {
    print("no hay usuarios registrados para esta ruta");
    return 1;
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
      return 2;
    }
  }
  return 0;
}

Future<String> create_poi(
  XFile? imageFile,
  String name,
  String description,
  double latitude,
  double longitude,
) async {
  final String url = "$baseUrl/create_poi";
  print('Creando POI con nombre $name en lat: $latitude, long: $longitude');

  if (!await _ensureEmail()) {
    return 'Error: Usuario no autenticado';
  }
  String? base64Image;
  if (imageFile != null) {
    final bytes = await imageFile.readAsBytes();
    base64Image = base64Encode(bytes);
  }

  final body = {
    "title": name,
    "description": description,
    "latitude": latitude,
    "longitude": longitude,
    "image": base64Image, // Puede ser null si no hay imagen
    "user_email": email,
  };

  // Espera a que la petición se complete antes de devolver algo
  final response = await http
      .post(
        Uri.parse(url),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(const Duration(seconds: 500));

  if (response.statusCode == 200) {
    print('POI creado exitosamente.');
    return response.body;
  } else {
    print('Falló la petición.');
    print("response---->${response.body}");
    throw Exception('Error al crear el POI');
  }
}

Future<List<dynamic>> get_pois_by_user_email(languageId) async {
  final String url = "$baseUrl/get_pois_by_user_email";

  if (!await _ensureEmail()) {
    return [];
  }

  var body = {"user_email": email, "language_id": languageId};

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  print("response---->${response?.body}, $body");
  if (response != null && response.statusCode == 200) {
    return jsonDecode(response.body)["data"];
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<dynamic>> get_relevant_pois(languageId) async {
  final String url = "$baseUrl/get_pois_with_zenodo_url";

  var body = {"language_id": languageId};

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  print("response---->${response?.body}, $body");
  if (response != null && response.statusCode == 200) {
    return jsonDecode(response.body)["data"];
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<LatLng>> two_points_route(lat1, long1, lat2, long2) async {
  final String url = "$baseUrl/two_points_route";

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "latitude1": lat1,
        "longitude1": long1,
        "latitude2": lat2,
        "longitude2": long2,
      }),
    ),
  );

  if (response != null && response.statusCode == 200) {
    List<dynamic> data = jsonDecode(response.body)["route"];
    print("response ------------->$data");
    return data.map<LatLng>((item) => LatLng(item[1], item[0])).toList();
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<dynamic>> get_pois_around_a_route(routeId, languageId) async {
  print(
    'Obteniendo puntos de interés alrededor de la ruta $routeId y el idioma $languageId',
  );

  // Intentar obtener desde caché primero
  final cacheKey = 'pois_around_route/$routeId';
  final params = {"language_id": languageId, "distance_km": "0.5"};

  final cachedData = await _getCachedApiResponse(cacheKey, params);

  if (cachedData != null) {
    print(
      '✅ Devolviendo POIs alrededor de ruta desde caché offline: ${(cachedData as List).length} POIs',
    );
    return cachedData;
  }

  // Si estamos en modo offline y no hay caché, retornar vacío
  if (_offlineMode) {
    print(
      '⚠️  Modo offline: no hay datos en caché para POIs alrededor de ruta $routeId',
    );
    return [];
  }

  final String url = "$baseUrl/get_pois_around_a_route";

  final body = {
    "route_id": routeId,
    "language_id": languageId,
    "distance_km": 0.5,
  };

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
    timeoutDuration: const Duration(seconds: 45),
  );

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];

    // Guardar en caché
    await _cacheApiResponse(cacheKey, params, data);

    return data;
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<dynamic> rate_poi(poiId, rating) async {
  print('Enviando rating $rating para el POI $poiId');
  final String url = "$baseUrl/rate_poi";
  final body = {"poi_id": poiId, "rating": rating, "user_id": idToken};
  print("body rating poi: $body");
  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  print("aaaaaaaaaaaaaa${response?.body}");
  return jsonDecode(response?.body ?? "{}")["data"];
}

Future<dynamic> rate_route(
  String routeId, {
  int? rating,
  String? comment,
}) async {
  print('Enviando reseña para la ruta $routeId');
  await _ensureIdToken();
  final String url = "$baseUrl/rate_route";
  final body = {
    "route_id": routeId,
    "user_id": idToken,
    if (rating != null) "rating": rating,
    if (comment != null && comment.isNotEmpty) "comment": comment,
  };
  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  if (response == null) return null;
  return jsonDecode(response.body)["data"];
}

Future<List<dynamic>> get_route_reviews(String routeId) async {
  await _ensureIdToken();
  final String url = "$baseUrl/get_route_reviews";
  final body = {"route_id": routeId, "user_id": idToken};
  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  if (response == null) return [];
  final data = jsonDecode(response.body)["data"];
  if (data is List) return data;
  return [];
}

Future<dynamic> getNearbyPois(
  String routeId,
  double latitude,
  double longitude,
  String languageId,
) async {
  await _ensureIdToken();

  // final latitude = 41.87290134635817;
  // final longitude = -8.16806124176333;
  final body = {
    "route_id": routeId,
    "latitude": latitude.toString(),
    "longitude": longitude.toString(),
    "distance": "0.5",
    "language_id": languageId,
    "user_id_token": idToken,
  };
  print("ID TOKEN $idToken");

  final String url = "$baseUrl/get_nearby_pois";
  return makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  ).then((response) {
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body)["data"];
      print('✅ POIs cercanos obtenidos: ${data?.length ?? 0}');
      return data;
    } else {
      print('Falló la petición definitivamente tras varios intentos.');
      if (response != null) {
        print(
          'Último estado: ${response.statusCode}. Cuerpo: ${response.body}',
        );
      }
      return [];
    }
  });
}

Future<dynamic> getRoutesNearbyALocation(
  double latitude,
  double longitude,
  String languageId, {
  double distanceKm = 2.0,
}) async {
  await _ensureIdToken();

  final body = {
    "latitude": latitude,
    "longitude": longitude,
    "distance": distanceKm,
    "language_id": languageId,
    "user_id_token": idToken,
  };

  final String url = "$baseUrl/get_routes_nearby_a_location";
  return makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  ).then((response) {
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body)["data"];
      print(data);
      print('✅ Rutas cercanas obtenidas: ${data?.length ?? 0}');
      return data ?? [];
    } else {
      print('Falló la petición de rutas cercanas.');
      if (response != null) {
        print(
          'Último estado: ${response.statusCode}. Cuerpo: ${response.body}',
        );
      }
      return [];
    }
  });
}

Future<dynamic> getEvents() {
  print('Obteniendo eventos cercanos');
  final String url = "$baseUrl/events";
  return makeRequestWithRetry(() => http.get(Uri.parse(url))).then((response) {
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body)["data"];
      print('✅ Eventos obtenidos: $data');
      return data;
    } else {
      print('Falló la petición definitivamente tras varios intentos.');
      if (response != null) {
        print(
          'Último estado: ${response.statusCode}. Cuerpo: ${response.body}',
        );
      }
      return [];
    }
  });
}

/// Crea una nueva ruta con los POIs seleccionados
///
/// Parámetros:
/// - [name]: Nombre de la ruta
/// - [shortDescription]: Descripción breve de la ruta
/// - [longDescription]: Descripción detallada de la ruta
/// - [routeType]: Tipo de ruta (e.g., "Camino de Santiago")
/// - [subtype]: Subtipo de ruta (opcional)
/// - [poiIds]: Lista de IDs de POIs que forman parte de la ruta
/// - [stageBreaks]: Lista de índices donde hay cambios de etapa
/// - [languageId]: ID del idioma para la ruta
/// - [imageBase64]: Imagen de portada en base64 (opcional)
Future<dynamic> createRoute({
  required String name,
  required String shortDescription,
  required String longDescription,
  required String routeType,
  String? subtype,
  required List<String> poiIds,
  List<int>? stageBreaks,
  required String languageId,
  String? imageBase64,
}) async {
  await _ensureIdToken();
  await _ensureEmail();

  print('Creando nueva ruta: $name');

  final body = {
    "name": name,
    "short_description": shortDescription,
    "long_description": longDescription,
    "route_type": routeType,
    if (subtype != null) "subtype": subtype,
    "poi_ids": poiIds,
    if (stageBreaks != null && stageBreaks.isNotEmpty)
      "stage_breaks": stageBreaks,
    "language_id": languageId,
    "user_id": idToken,
    "owner": email,
    "visibility": "private",
    if (imageBase64 != null) "image_base64": imageBase64,
  };

  final String url = "$baseUrl/create_route";

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];
    print('✅ Ruta creada exitosamente: $data');
    return data;
  } else {
    print('❌ Falló la creación de la ruta tras varios intentos.');
    print('Último estado: ${response?.statusCode}. Cuerpo: ${response?.body}');
    throw Exception('Error al crear la ruta');
  }
}

/// Obtiene POIs en una región específica del mapa
///
/// Parámetros:
/// - [north]: Latitud norte del área visible
/// - [south]: Latitud sur del área visible
/// - [east]: Longitud este del área visible
/// - [west]: Longitud oeste del área visible
/// - [languageId]: ID del idioma para los POIs
Future<List<dynamic>> getPoisInRegion({
  required double north,
  required double south,
  required double east,
  required double west,
  required String languageId,
}) async {
  await _ensureIdToken();

  print('Obteniendo POIs en región: N:$north, S:$south, E:$east, W:$west');

  // Calcular el centro de la región
  final centerLat = (north + south) / 2;
  final centerLon = (east + west) / 2;

  // Calcular la distancia aproximada del centro a las esquinas (en km)
  // Esto nos da un radio aproximado de búsqueda
  final latDiff = (north - south).abs();
  final lonDiff = (east - west).abs();
  final distance =
      ((latDiff + lonDiff) / 2) * 111; // Aproximación simple: 1 grado ≈ 111 km

  final body = {
    "north": north,
    "south": south,
    "east": east,
    "west": west,
    "language_id": languageId,
  };

  final String url = "$baseUrl/get_pois_in_a_region";

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];
    print('✅ POIs en región obtenidos: ${data?.length ?? 0}');
    return data ?? [];
  } else {
    print('❌ Falló la petición de POIs en región.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

Future<List<dynamic>> getMyRoutes(String languageId) async {
  print('Obteniendo mis rutas creadas para el usuario $email');
  final String url = "$baseUrl/get_my_routes";

  if (!await _ensureEmail()) {
    return [];
  }

  final body = {"user_email": email, "language_id": languageId};
  const cacheKey = 'my_routes';

  // Comprobar conectividad: solo usar caché si no hay internet
  final connectivityResult = await Connectivity().checkConnectivity();
  final hasConnection = connectivityResult != ConnectivityResult.none;

  if (_offlineMode || !hasConnection) {
    final cachedData = await _getCachedApiResponse(cacheKey, body);
    if (cachedData != null) {
      print('Devolviendo mis rutas desde caché offline');
      return cachedData as List<dynamic>;
    }
    print('Sin conexión y sin caché para mis rutas');
    return [];
  }

  final response = await makeRequestWithRetry(
    () => http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  print("response---->${response?.body}, $body");
  if (response != null && response.statusCode == 200) {
    final data = jsonDecode(response.body)["data"];
    await _cacheApiResponse(cacheKey, body, data);
    return data;
  } else {
    print('Falló la petición definitivamente tras varios intentos.');
    if (response != null) {
      print('Último estado: ${response.statusCode}. Cuerpo: ${response.body}');
    }
    return [];
  }
}

/// Elimina una ruta creada por el usuario
///
/// Parámetros:
/// - [routeId]: ID de la ruta a eliminar
Future<bool> deleteRoute(String routeId) async {
  await _ensureIdToken();
  await _ensureEmail();

  print('Eliminando ruta: $routeId');

  final String url = "$baseUrl/delete_route/$routeId";

  final response = await makeRequestWithRetry(
    () => http.delete(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (response != null && response.statusCode == 200) {
    print('✅ Ruta eliminada exitosamente');
    return true;
  } else {
    print('❌ Falló la eliminación de la ruta tras varios intentos.');
    print('Último estado: ${response?.statusCode}. Cuerpo: ${response?.body}');
    return false;
  }
}

/// Obtiene todos los audios disponibles
///
/// Retorna una lista de audios con su metadata
Future<List<Map<String, dynamic>>> getAllAudios() async {
  print('Obteniendo todos los audios disponibles');

  final cacheKey = 'all_audios';
  final cacheParams = <String, dynamic>{};

  // Intentar obtener desde caché si corresponde
  if (_shouldUseCache()) {
    final cachedData = await _getCachedApiResponse(cacheKey, cacheParams);
    if (cachedData != null) {
      print('✅ Devolviendo audios desde caché');
      return List<Map<String, dynamic>>.from(cachedData as List);
    }
  }

  // Si no se debe hacer petición (offline sin caché), retornar vacío
  if (!_shouldMakeRequest()) {
    print('⚠️ Modo offline: no hay datos en caché para audios');
    return [];
  }

  print('🌐 Obteniendo audios del servidor');

  final String url = "$baseUrl/get_all_audios";

  final response = await makeRequestWithRetry(() => http.get(Uri.parse(url)));

  if (response != null && response.statusCode == 200) {
    final jsonData = jsonDecode(response.body);
    if (jsonData['status'] == 'ok') {
      final List<dynamic> data = jsonData['data'];
      final audiosList = List<Map<String, dynamic>>.from(data);
      await _cacheApiResponse(cacheKey, cacheParams, audiosList);
      print('✅ ${audiosList.length} audios obtenidos exitosamente');
      return audiosList;
    } else {
      print('❌ Error en la respuesta: ${jsonData['status']}');
      return [];
    }
  } else {
    print('❌ Falló la petición de audios tras varios intentos.');
    print('Último estado: ${response?.statusCode}. Cuerpo: ${response?.body}');
    return [];
  }
}

/// Obtiene la URL completa de un audio específico
///
/// Parámetros:
/// - [audioId]: ID del audio a obtener
String getAudioUrl(String audioId) {
  return "$baseUrl/get_audio/$audioId";
}
