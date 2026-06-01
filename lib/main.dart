// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// shared_preferences handled inside providers when needed
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Core
import 'core/config/routes.dart';
import 'core/config/theme.dart';

// Services
import 'services/firebase/firebase_service.dart';
import 'services/firebase/fcm_service.dart';
import 'services/background/route_tracking_service.dart';
// auth_service handled inside repository when needed
// Repositorios
import 'data/repositories/auth_repository.dart';
import 'services/haptic/haptic_service.dart';

// Providers
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/route_provider.dart';
import 'presentation/providers/offline_provider.dart';
import 'presentation/providers/connectivity_provider.dart';
import 'presentation/providers/audio_player_provider.dart';
import 'presentation/providers/audio_provider.dart';

// Widgets
import 'presentation/widgets/floating_audio_player.dart';

/// 🚀 PUNTO DE ENTRADA DE LA APLICACIÓN
void main() async {
  // 1️⃣ Inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Habilitar modo edge-to-edge (extremo a extremo) para Android 15+
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 3️⃣ Bloquear orientación en portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 3️⃣ Inicializar Firebase
  await FirebaseService.initialize();

  // 3️⃣.1 Registrar handler de FCM en background
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 4️⃣ Inicializar servicio de tracking de rutas
  await RouteService.initialize();

  // 5️⃣ Inicializar servicios
  await HapticService().initialize();

  // 6️⃣ Ejecutar la aplicación
  runApp(const MyApp());
}
// Nota: ThemeProvider y LocaleProvider gestionan sus propias preferencias.

/// 🎨 APLICACIÓN PRINCIPAL
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider de idioma
        ChangeNotifierProvider(create: (_) => LocaleProvider(), lazy: true),

        // Provider de tema
        ChangeNotifierProvider(create: (_) => ThemeProvider(), lazy: true),

        // Exponer el repositorio de autenticación para usos directos
        Provider<AuthRepository>(
          create: (_) => AuthRepository(),
          dispose: (_, repo) {},
        ),

        // Provider de autenticación (ChangeNotifier)
        ChangeNotifierProvider(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
        ),

        // Provider de rutas
        ChangeNotifierProvider<RouteProvider>(
          create: (context) => RouteProvider(),
        ),

        // Provider de audios
        ChangeNotifierProvider<AudioProvider>(
          create: (context) => AudioProvider(),
        ),

        // Provider global del reproductor de audio
        ChangeNotifierProvider<AudioPlayerProvider>(
          create: (context) => AudioPlayerProvider(),
        ),

        // Provider de modo offline (solo en apps nativas)
        if (!kIsWeb)
          ChangeNotifierProvider<OfflineProvider>(
            create: (context) => OfflineProvider()..initialize(),
          ),

        // Provider de conectividad (solo en apps nativas)
        if (!kIsWeb)
          ChangeNotifierProvider<ConnectivityProvider>(
            create: (context) => ConnectivityProvider(),
          ),
      ],
      child: const _MaterialAppWrapper(),
    );
  }
}

/// Wrapper para MaterialApp con acceso a los providers
class _MaterialAppWrapper extends StatefulWidget {
  const _MaterialAppWrapper();

  @override
  State<_MaterialAppWrapper> createState() => _MaterialAppWrapperState();
}

class _MaterialAppWrapperState extends State<_MaterialAppWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Inicializa servicios que requieren contexto
  Future<void> _initializeServices() async {
    try {
      // Cargar credenciales guardadas
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadSavedCredentials();

      // Inicializar FCM (instancia)
      await FCMService().initialize(navigatorKey);

      setState(() {
        _isInitialized = true;
      });

      debugPrint('✅ Servicios inicializados correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando servicios: $e');

      setState(() {
        _isInitialized = true; // Continuar aunque falle
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar splash mientras se inicializan servicios
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashScreen(),
      );
    }

    // Aplicación principal
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, _) {
        return MaterialApp.router(
          // 📱 Configuración básica
          debugShowCheckedModeBanner: false,
          title: 'Pilgrims 3D',

          // Envolver todo el contenido en SafeArea para evitar la barra de navegación
          builder: (context, child) {
            final audioPlayerProvider = Provider.of<AudioPlayerProvider>(
              context,
            );

            return SafeArea(
              top: false,
              bottom: true,
              child: Stack(
                children: [
                  // Contenido principal de la app
                  child ?? const SizedBox.shrink(),

                  // Reproductor flotante global
                  if (audioPlayerProvider.hasAudio)
                    FloatingAudioPlayer(
                      audioPlayer: audioPlayerProvider.audioPlayer,
                      currentAudio: audioPlayerProvider.currentAudio,
                      onClose: () {
                        audioPlayerProvider.stop();
                      },
                    ),
                ],
              ),
            );
          },

          // 🎨 Temas
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          // 🌍 Internacionalización
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('es', ''),
            Locale('fr', ''),
            Locale('pt', ''),
            Locale('it', ''),
            Locale('de', ''),
            Locale('ca', ''),
            Locale('gl', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // 🧭 Navegación
          routerConfig: AppRouter.router,
        );
      },
    );
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}

/// Widget optimizado de splash screen
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.landscape, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Pilgrims 3D',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
