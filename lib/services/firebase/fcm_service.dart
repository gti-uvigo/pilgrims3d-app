import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:pilgrims_3d/presentation/dialogs/fcm_dialogs.dart';
import 'package:pilgrims_3d/services/firebase/firebase_service.dart';
import '../../core/config/env.dart';

/// Handler de mensajes FCM en background.
/// Debe ser top-level y con entry-point para que el runtime lo encuentre.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el isolate de background
  await FirebaseService.initialize();

  debugPrint('📩 FCM background: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');

  // Aquí solo lógica ligera (sin UI). Si necesitas notificación local,
  // usa un plugin específico y disparamos desde aquí.

  // Usar switch para mejor rendimiento
  final title =
      (message.data['title'] ?? message.notification?.title)?.toString();
  final body = (message.data['body'] ?? message.notification?.body)?.toString();

  switch (title) {
    case 'Nearby POIs':
      if (message.notification == null) {
        _handleNearbyPoisNotificationBackground(body);
      } else {
        debugPrint(
          'ℹ️ Notificación del SO mostrada. Evitando duplicado local.',
        );
      }
      break;

    default:
      debugPrint("ℹ️ Notificación sin handler: $title");
  }
}

Future<void> _handleNearbyPoisNotificationBackground(String? body) async {
  if (body == null || body.isEmpty) return;

  try {
    // Inicializar plugins en background
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel poisChannel = AndroidNotificationChannel(
      'nearby_pois_channel',
      'Puntos de Interés Cercanos',
      description: 'Notificaciones de POIs detectados cerca de tu ubicación',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(poisChannel);

    final poi = _parsePoiFromBody(body);

    if (poi == null) return;

    final String name =
        (poi['title'] ?? poi['name'] ?? 'Lugar de interés').toString().trim();
    final String description =
        (poi['description'] ?? 'Descubre este lugar cercano').toString().trim();
    final String? minutes = poi['minutes_duration']?.toString();

    final String subtitle =
        minutes != null && minutes.isNotEmpty
            ? '⏱️ $minutes'
            : '📍 Cerca de tu ubicación';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'nearby_pois_channel',
          'Puntos de Interés Cercanos',
          channelDescription:
              'Notificaciones de POIs detectados cerca de tu ubicación',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            description,
            contentTitle: '🎯 $name',
            summaryText: subtitle,
          ),
          enableVibration: true,
          playSound: true,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await notificationsPlugin.show(
      997,
      '🎯 POI cercano detectado',
      '$name · $subtitle',
      details,
      payload: body,
    );
  } catch (e) {
    debugPrint('❌ Error mostrando notificación de POIs (background): $e');
  }
}

@pragma('vm:entry-point')
void localNotificationTapBackground(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_poi_notification_payload', payload);
}

String _sanitizeJsonStringBackground(String body) {
  return body
      .replaceAll("'''", '')
      .replaceAll("'", '"')
      .replaceAll('None', 'null')
      .replaceAll('True', 'true')
      .replaceAll('False', 'false');
}

Map<String, dynamic>? _parsePoiFromBody(String body) {
  try {
    final jsonBody = _sanitizeJsonStringBackground(body);
    final parsed = jsonDecode(jsonBody);
    if (parsed is Map<String, dynamic>) return parsed;
    if (parsed is List && parsed.isNotEmpty) {
      final first = parsed.first;
      if (first is Map<String, dynamic>) return first;
    }
  } catch (_) {}
  return null;
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _token;
  GlobalKey<NavigatorState>? _navigatorKey;

  String? get token => _token;

  Future<void> _initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          localNotificationTapBackground,
    );

    const AndroidNotificationChannel poisChannel = AndroidNotificationChannel(
      'nearby_pois_channel',
      'Puntos de Interés Cercanos',
      description: 'Notificaciones de POIs detectados cerca de tu ubicación',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(poisChannel);
  }

  Future<void> _consumePendingPoiPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString('pending_poi_notification_payload');
    if (payload == null || payload.isEmpty) return;
    await prefs.remove('pending_poi_notification_payload');
    _handleNearbyPoisTap(payload);
  }

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    await _initializeLocalNotifications();
    await _consumePendingPoiPayload();
    // Solicitar permisos (especialmente importante en iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print(
      'Permisos de notificación: [32m[1m${settings.authorizationStatus}[0m',
    );

    // Obtener el token FCM
    if (!kIsWeb) {
      // En iOS, getToken() requiere que el APNs token esté disponible primero.
      // En simulador no hay APNs, por lo que el token FCM siempre será null.
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        String? apnsToken;
        // Esperar hasta 10 s a que el sistema registre el APNs token
        for (int i = 0; i < 10; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          debugPrint(
            '⚠️ APNs token no disponible (¿simulador?). FCM token no se puede obtener.',
          );
        } else {
          _token = await _messaging.getToken();
          debugPrint("Token FCM (iOS): $_token");
          notificationsToken = _token ?? "";
        }
      } else {
        _token = await _messaging.getToken();
        debugPrint("Token FCM: $_token");
        notificationsToken = _token ?? "";
      }
    }

    // Listener para cuando el token se actualice
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      print("Token FCM actualizado: $newToken");
      // Aquí podrías enviar el token a tu backend
    });

    // Listener cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Mensaje en foreground: ${message.notification?.title}");
      print("Cuerpo: ${message.notification?.body}");
      print("Data: ${message.data}");
      _handleForegroundMessage(message);
    });

    // Listener cuando el usuario abre una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notificación abierta: ${message.notification?.title}");
      print("Data: ${message.data}");
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print(
        "App abierta desde notificación: ${initialMessage.notification?.title}",
      );
      _handleNotificationTap(initialMessage);
    }
  }

  // Debouncing para evitar múltiples intentos
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;

  void _handleForegroundMessage(RemoteMessage message) {
    // Mostrar un popup con el contenido del mensaje
    debugPrint("🔔 Intentando mostrar diálogo...");

    final context = _navigatorKey?.currentContext;

    if (context == null) {
      debugPrint("❌ Error: NavigatorKey.currentContext es null");

      // Solo reintentar un número limitado de veces
      if (_retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        Future.delayed(Duration(milliseconds: 100 * _retryAttempts), () {
          if (_navigatorKey?.currentContext != null) {
            _handleForegroundMessage(message);
          }
        });
      } else {
        debugPrint("❌ Se alcanzó el límite de reintentos");
        _retryAttempts = 0;
      }
      return;
    }

    // Resetear contador al tener éxito
    _retryAttempts = 0;

    if (!context.mounted) {
      debugPrint("❌ Error: El contexto no está montado");
      return;
    }

    debugPrint("✅ Mostrando diálogo para: ${message.notification?.title}");

    // Usar switch para mejor rendimiento
    final title =
        (message.data['title'] ?? message.notification?.title)?.toString();
    final body =
        (message.data['body'] ?? message.notification?.body)?.toString();

    switch (title) {
      case 'SOS Alert':
        getSOSdialog(context, body);
        break;
      case 'Nearby POIs':
        _handleNearbyPoisNotification(context, body);
        break;
      case 'POI Created Successfully':
        poiCreatedSuccessfully(context);
        break;
      case 'POI Inappropriate Content':
        poiInappropriateContent(context, body);
        break;
      default:
        debugPrint("ℹ️ Notificación sin handler: $title");
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final title =
        (message.data['title'] ?? message.notification?.title)?.toString();
    final body =
        (message.data['body'] ?? message.notification?.body)?.toString();

    debugPrint("📱 Notificación tocada: $title");

    switch (title) {
      case 'SOS Alert':
        _handleSOSAlertTap(body);
        break;
      case 'Nearby POIs':
        _handleNearbyPoisTap(body);
        break;
      default:
        debugPrint("ℹ️ Tap en notificación sin handler: $title");
    }
  }

  void _handleSOSAlertTap(String? messageBody) {
    if (messageBody == null || messageBody.isEmpty) return;

    final parts = messageBody.split(',');
    if (parts.length != 2) {
      debugPrint("❌ Formato de coordenadas inválido: $messageBody");
      return;
    }

    final latDouble = double.tryParse(parts[0].trim());
    final longDouble = double.tryParse(parts[1].trim());

    if (latDouble == null || longDouble == null) {
      debugPrint("❌ No se pueden convertir las coordenadas a números");
      return;
    }

    final context = _navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      debugPrint("🗺️ Navegando a SOS Alert: $latDouble, $longDouble");
      context.pushNamed(
        'navigationMap',
        extra: {
          'destinationLatitude': latDouble,
          'destinationLongitude': longDouble,
          'destinationName': 'SOS Alert',
        },
      );
    }
  }

  void _handleNearbyPoisNotification(BuildContext context, String? body) {
    if (body == null || body.isEmpty) return;

    try {
      // El cuerpo viene con formato Python, convertir a JSON válido
      final jsonBody = _sanitizeJsonString(body);

      // Parsear el JSON - puede ser un Map o una List
      final parsed = jsonDecode(jsonBody);
      final List pois =
          parsed is List ? parsed : (parsed is Map ? [parsed] : []);

      if (pois.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No hay POIs cercanos')));
        }
        return;
      }

      // Mostrar diálogo con los POIs cercanos
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('POIs Cercanos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${pois.length} POI(s) encontrados cerca de ti'),
                    const SizedBox(height: 16),
                    ...pois.take(3).map((poi) {
                      final title = poi['title'];

                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(title ?? 'POI'),
                        subtitle:
                            poi['minutes_duration'] != null
                                ? Text(poi['minutes_duration'])
                                : null,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToNearbyPoi(poi);
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToNearbyPoi(pois.first);
                  },
                  child: const Text('Ir al más cercano'),
                ),
              ],
            ),
      );
    } catch (e) {
      print('❌ Error parseando POIs cercanos: $e');
    }
  }

  /// Helper para sanitizar strings con formato Python a JSON válido
  String _sanitizeJsonString(String body) {
    return body
        .replaceAll("'''", '') // Eliminar comillas triples
        .replaceAll("'", '"') // Convertir comillas simples a dobles
        .replaceAll('None', 'null')
        .replaceAll('True', 'true')
        .replaceAll('False', 'false');
  }

  void _handleNearbyPoisTap(String? body) {
    if (body == null || body.isEmpty) return;

    try {
      // Convertir formato Python a JSON válido
      final jsonBody = _sanitizeJsonString(body);

      // Parsear el JSON - puede ser un Map o una List
      final parsed = jsonDecode(jsonBody);
      List pois = [];

      if (parsed is List) {
        pois = parsed;
      } else if (parsed is Map) {
        pois = [parsed];
      }

      if (pois.isNotEmpty) {
        _navigateToNearbyPoi(pois.first);
      }
    } catch (e) {
      print('❌ Error parseando POIs: $e');
    }
  }

  void _navigateToNearbyPoi(Map<String, dynamic> poi) {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    final lat = poi['latitude'];
    final lon = poi['longitude'];
    final titles = poi['titles'] as List?;
    final title = titles?.firstWhere(
      (t) => t['language_id'] == '6d68e409-c46e-4d4a-8560-f15256e9cbb3',
      orElse: () => titles.first,
    );
    final name = title?['text'] ?? 'POI Cercano';

    if (lat != null && lon != null) {
      context.pushNamed(
        'navigationMap',
        extra: {
          'destinationLatitude': lat as double,
          'destinationLongitude': lon as double,
          'destinationName': name,
        },
      );
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print("Suscrito al topic: $topic");
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print("Desuscrito del topic: $topic");
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _handleNearbyPoisTap(payload);
  }

  Future<void> _showNearbyPoisLocalNotification(String? body) async {
    if (body == null || body.isEmpty) return;

    final poi = _parsePoiFromBody(body);
    if (poi == null) return;

    final String name =
        (poi['title'] ?? poi['name'] ?? 'Lugar de interés').toString().trim();
    final String description =
        (poi['description'] ?? 'Descubre este lugar cercano').toString().trim();
    final String? minutes = poi['minutes_duration']?.toString();

    final String subtitle =
        minutes != null && minutes.isNotEmpty
            ? '⏱️ $minutes'
            : '📍 Cerca de tu ubicación';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'nearby_pois_channel',
          'Puntos de Interés Cercanos',
          channelDescription:
              'Notificaciones de POIs detectados cerca de tu ubicación',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            description,
            contentTitle: '🎯 $name',
            summaryText: subtitle,
          ),
          enableVibration: true,
          playSound: true,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      997,
      '🎯 POI cercano detectado',
      '$name · $subtitle',
      details,
      payload: body,
    );
  }
}
