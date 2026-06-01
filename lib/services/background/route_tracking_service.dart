import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';

class RouteService {
  static const String notificationChannelId = 'route_tracking_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    // Solo inicializar en plataformas móviles (Android/iOS)
    if (kIsWeb) {
      print('⚠️ RouteService no disponible en Web');
      return;
    }

    final service = FlutterBackgroundService();

    // Configuración de notificaciones para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Seguimiento de Ruta',
      description: 'Mantiene el GPS activo cada 10 segundos',
      importance: Importance.low, // Importancia baja para que no moleste
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Crear canal para notificaciones de POIs cercanos
    const AndroidNotificationChannel poisChannel = AndroidNotificationChannel(
      'nearby_pois_channel',
      'Puntos de Interés Cercanos',
      description: 'Notificaciones de POIs detectados cerca de tu ubicación',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(poisChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Lo iniciaremos manualmente
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: '🥾 Seguimiento de Ruta Activo',
        initialNotificationContent: 'Monitoreando tu ubicación y buscando puntos de interés cercanos...',
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}



@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Escuchar cuando queramos detener el servicio
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // El bucle de 10 segundos
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        timer.cancel(); // Si el servicio se detiene, paramos el timer
        return;
      }
    }

    // --- AQUÍ VA TU LÓGICA ---
    final prefs = await SharedPreferences.getInstance();
    final routeId = prefs.getString('active_route_id') ?? "Desconocida";
    
    print('📍 [${DateTime.now()}] Ejecutando tracking de: $routeId');

    // Obtener ubicación actual
    try {
      final position = await getCurrentLocation();      
      final languageId = prefs.getString('active_language_id') ?? "en";
      
      // Buscar POIs cercanos
      final nearbyPoisResponse = await getNearbyPois(routeId, position.latitude, position.longitude, languageId);
      
      // Manejar tanto Map como List
      Map<String, dynamic>? currentPoi;
      if (nearbyPoisResponse is Map<String, dynamic>) {
        // Si es un Map, es un solo POI
        currentPoi = nearbyPoisResponse;
        print('🎯 POI cercano encontrado: ${currentPoi['name']}');
      } else if (nearbyPoisResponse is List && nearbyPoisResponse.isNotEmpty) {
        // Si es una lista, tomar el primero
        currentPoi = nearbyPoisResponse[0];
        print('🎯 POIs cercanos encontrados: ${nearbyPoisResponse.length}');
      } else {
        print('🎯 No hay POIs cercanos');
      }
      
      // Si hay un POI, verificar si es nuevo
      if (currentPoi != null) {
        final currentPoiId = currentPoi['id']?.toString() ?? '';
        final lastNotifiedPoiId = prefs.getString('last_notified_poi_id') ?? '';
        
        // Solo notificar si es un POI diferente al último
        if (currentPoiId.isNotEmpty && currentPoiId != lastNotifiedPoiId) {
          await prefs.setString('last_notified_poi_id', currentPoiId);
          
          // Mostrar notificación del POI cercano
          await _showNearbyPoisNotification(
            flutterLocalNotificationsPlugin,
            currentPoi,
          );
        }
      } else {
        // Resetear el último POI notificado si no hay POIs cercanos
        await prefs.remove('last_notified_poi_id');
      }
      
      // Actualizar la notificación de background con información bonita
      if (service is AndroidServiceInstance) {
        final poisInfo = currentPoi != null ? '🎯 1 punto de interés cercano' : '🔍 Buscando lugares...';
        await service.setForegroundNotificationInfo(
          title: '🥾 Ruta en Progreso',
          content: '📍 ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}\n$poisInfo',
        );
      }
    } catch (e) {
      print('⚠️: $e');
      // En caso de error, mostrar notificación de estado
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: '🥾 Ruta en Progreso',
          content: '⚠️ Esperando señal GPS...',
        );
      }
    }


    // Enviar datos a la UI si la app está abierta
    service.invoke('update', {
      "time": DateTime.now().toIso8601String(),
      "route": routeId,
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Obtiene la ubicación actual del dispositivo
Future<Position> getCurrentLocation() async {
  try {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('⚠️ Servicio de ubicación deshabilitado');
      throw Exception('Servicio de ubicación deshabilitado');
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('⚠️ Permisos de ubicación denegados');
        throw Exception('Permisos de ubicación denegados');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('⚠️ Permisos de ubicación denegados permanentemente');
      throw Exception('Permisos de ubicación denegados permanentemente');
    }

    // Obtener ubicación actual
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print('📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}');
    return position;
  } catch (e) {
    print('❌ Error obteniendo ubicación: $e');
    rethrow;
  }
}

/// Muestra una notificación bonita cuando se detecta un nuevo POI cercano
Future<void> _showNearbyPoisNotification(
  FlutterLocalNotificationsPlugin notificationsPlugin,
  Map<String, dynamic> poi,
) async {
  try {
    // Obtener información del POI
    String name = 'Lugar de interés';
    String description = 'Descubre este lugar cercano';
    
    // Extraer el título del POI (maneja estructura de titles)
    if (poi['titles'] != null && poi['titles'] is List) {
      final titles = poi['titles'] as List;
      if (titles.isNotEmpty) {
        // Intentar obtener el título en español (language_id específico) o el primero disponible
        final title = titles.firstWhere(
          (t) => t['language_id'] == '6d68e409-c46e-4d4a-8560-f15256e9cbb3',
          orElse: () => titles.first,
        );
        name = title['text'] ?? name;
      }
    } else if (poi['name'] != null) {
      name = poi['name'].toString();
    }
    
    // Extraer descripción
    if (poi['descriptions'] != null && poi['descriptions'] is List) {
      final descriptions = poi['descriptions'] as List;
      if (descriptions.isNotEmpty) {
        final desc = descriptions.firstWhere(
          (d) => d['language_id'] == '6d68e409-c46e-4d4a-8560-f15256e9cbb3',
          orElse: () => descriptions.first,
        );
        description = desc['text'] ?? description;
      }
    } else if (poi['description'] != null) {
      description = poi['description'].toString();
    }
    
    final distance = poi['distance'] ?? 0;
    final distanceText = distance < 1000 
        ? '${distance.toStringAsFixed(0)}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'nearby_pois_channel',
      'Puntos de Interés Cercanos',
      channelDescription: 'Notificaciones de POIs detectados cerca de tu ubicación',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        description,
        contentTitle: '🎯 ¡$name a $distanceText!',
        summaryText: 'Toca para ver detalles',
      ),
      enableVibration: true,
      playSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await notificationsPlugin.show(
      999, // ID fijo - se reemplaza la notificación anterior
      '🎯 ¡Lugar descubierto cerca!',
      '$name a $distanceText',
      notificationDetails,
    );
  } catch (e) {
    print('❌ Error mostrando notificación de POIs: $e');
  }
}
