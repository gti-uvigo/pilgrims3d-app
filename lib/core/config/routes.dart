import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pilgrims_3d/presentation/screens/about_screen.dart';
import 'package:pilgrims_3d/presentation/screens/all_routes_map_screen.dart';
import 'package:pilgrims_3d/presentation/screens/nearby_routes_map_screen.dart';
import 'package:pilgrims_3d/presentation/screens/ar_screen.dart';
import 'package:pilgrims_3d/presentation/screens/create_poi_screen.dart';
import 'package:pilgrims_3d/presentation/screens/model3d_screen.dart';
import 'package:pilgrims_3d/presentation/screens/my_pois_screen.dart';
import 'package:pilgrims_3d/presentation/screens/navigation_map_screen.dart';
import 'package:pilgrims_3d/presentation/screens/one_route_map_screen.dart';
import 'package:pilgrims_3d/presentation/screens/route_stages_screen.dart';
import 'package:pilgrims_3d/presentation/screens/relevant_pois_screen.dart';
import 'package:pilgrims_3d/presentation/screens/poi_detail_screen.dart';
import 'package:pilgrims_3d/presentation/screens/create_route_screen.dart';
import 'package:pilgrims_3d/presentation/screens/my_routes_screen.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/core/utils/initial_location_stub.dart'
    if (dart.library.html) 'package:pilgrims_3d/core/utils/initial_location_web.dart';

// Screens
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/events_screen.dart';
import '../../presentation/screens/audios_screen.dart';
import '../../presentation/screens/login_screen.dart';
// Imports para pantallas adicionales comentadas (evitar imports no usados)
import '../../presentation/screens/terms_screen.dart';
import '../../presentation/screens/privacy_policy_screen.dart';
import '../../presentation/screens/delete_account_screen.dart';
import '../../presentation/screens/survey_screen.dart';

/// Global Navigator Key para acceder al contexto desde cualquier lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Configuración de rutas de la aplicación usando GoRouter
class AppRouter {
  // Flag global para indicar si la sesión actual es de invitado
  static bool guestMode = false;
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: getInitialLocation(),

    // Rutas de la aplicación
    routes: [
      // 🔓 RUTAS PÚBLICAS (sin autenticación)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => LoginScreen(),
      ),

      GoRoute(
        path: '/poi/:poiId',
        name: 'poiDetail',
        builder: (context, state) {
          final poiId = state.pathParameters['poiId'];
          if (poiId == null || poiId.isEmpty) {
            return const HomeScreen();
          }
          return PoiDetailScreen(poiId: poiId);
        },
      ),

      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsAndConditionsScreen(),
      ),

      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),

      GoRoute(
        path: '/delete_account',
        name: 'deleteAccount',
        builder: (context, state) => const DeleteAccountScreen(),
      ),

      // 🔒 RUTAS PRIVADAS (requieren autenticación)
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => const EventsScreen(),
      ),

      GoRoute(
        path: '/audios',
        name: 'audios',
        builder: (context, state) => const AudiosScreen(),
      ),

      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),

      GoRoute(
        path: '/survey',
        name: 'survey',
        builder: (context, state) => const SurveyScreen(),
      ),

      GoRoute(
        path: '/route',
        name: 'route',
        redirect: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null ||
              args['routeId'] == null ||
              args['routeName'] == null) {
            return '/';
          }
          return null;
        },
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return RouteStagesScreen(
            routeName: args?['routeName'] ?? '',
            routeId: args?['routeId'] ?? '',
          );
        },
      ),

      GoRoute(
        path: '/map',
        name: 'map',
        redirect: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null || args['routeId'] == null) {
            return '/';
          }
          return null;
        },
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final routeId = args?['routeId'] ?? '';
          final routeName = args?['routeName'] ?? routeId;
          final pois = args?['pois'] as List<dynamic>? ?? [];

          return OneRouteMapScreen(
            routeId: routeId,
            routeName: routeName,
            pois: pois,
          );
        },
      ),

      GoRoute(
        path: '/navigationMap',
        name: 'navigationMap',
        redirect: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null ||
              args['destinationLatitude'] == null ||
              args['destinationLongitude'] == null) {
            return '/';
          }
          return null;
        },
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final destinationLatitude =
              (args?['destinationLatitude'] as num?)?.toDouble() ?? 0.0;
          final destinationLongitude =
              (args?['destinationLongitude'] as num?)?.toDouble() ?? 0.0;
          final destinationName = args?['destinationName'] as String?;

          return NavigationMapScreen(
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
            destinationName: destinationName,
          );
        },
      ),

      GoRoute(
        path: '/nearbyRoutesMap',
        name: 'nearbyRoutesMap',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final languageId = args?['languageId'] as String? ?? '1';
          final distanceKm = (args?['distanceKm'] as num?)?.toDouble() ?? 2.0;

          return NearbyRoutesMapScreen(
            languageId: languageId,
            distanceKm: distanceKm,
          );
        },
      ),

      GoRoute(
        path: '/allRoutesMap',
        name: 'allRoutesMap',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final routeType = args?['routeType'] ?? 'all';
          final languageId = args?['languageId'] ?? '1';

          return AllRoutesMapScreen(
            routeType: routeType,
            languageId: languageId,
          );
        },
      ),

      GoRoute(
        path: '/model-viewer',
        name: 'modelViewer',
        builder: (context, state) {
          final modelUrl =
              state.uri.queryParameters['modelUrl'] ??
              'https://zenodo.org/api/files/2bc7f5fc-94c3-48ad-aec1-d2d6d9c649c0/23343bb4baae43bb87399264ade89547.glb';
          return ModelViewerScreen(modelUrl: modelUrl);
        },
      ),

      GoRoute(
        path: '/create_poi',
        name: 'createPoi',
        redirect: (context, state) {
          final loggedIn = FirebaseAuth.instance.currentUser != null;
          if (!loggedIn || AppRouter.guestMode) return '/login';
          return null;
        },
        builder: (context, state) => const CreatePOIScreen(),
      ),

      GoRoute(
        path: '/my_pois',
        name: 'myPois',
        redirect: (context, state) {
          final loggedIn = FirebaseAuth.instance.currentUser != null;
          if (!loggedIn || AppRouter.guestMode) return '/login';
          return null;
        },
        builder: (context, state) => const MyPoisScreen(),
      ),

      GoRoute(
        path: '/create_route',
        name: 'createRoute',
        redirect: (context, state) {
          final loggedIn = FirebaseAuth.instance.currentUser != null;
          if (!loggedIn || AppRouter.guestMode) return '/login';
          return null;
        },
        builder: (context, state) => const MapRouteCreatorScreen(),
      ),

      GoRoute(
        path: '/my_routes',
        name: 'myRoutes',
        redirect: (context, state) {
          final loggedIn = FirebaseAuth.instance.currentUser != null;
          if (!loggedIn || AppRouter.guestMode) return '/login';
          return null;
        },
        builder: (context, state) => const MyRoutesScreen(),
      ),

      GoRoute(
        path: '/relevant_pois',
        name: 'relevantPois',
        builder: (context, state) => const RelevantPoisScreen(),
      ),

      GoRoute(
        path: '/arScreen',
        name: 'arScreen',
        builder: (context, state) {
          final modelUrl = state.uri.queryParameters['modelUrl'];
          return ARScreen(modelUrl: modelUrl);
        },
      ),
    ],

    // Redirect global para proteger rutas
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      // En web: uri.path; en mobile: matchedLocation
      final location =
          state.uri.path.isNotEmpty ? state.uri.path : state.matchedLocation;
      final loggingIn = location == '/login';
      final isPublicRoute = _isPublicRoute(location);
      final isGuest = AppRouter.guestMode;

      debugPrint(
        '🔐 Redirect check: location=$location, loggedIn=$loggedIn, isPublic=$isPublicRoute',
      );

      // Si no está logueado ni en modo invitado y no está en una ruta pública, redirigir a login
      if (!loggedIn && !isGuest && !isPublicRoute) {
        debugPrint('❌ Redirigiendo a login de: $location');
        return '/login';
      }

      // Si está logueado o es invitado y está en login, redirigir a home
      if ((loggedIn || isGuest) && loggingIn) {
        debugPrint('→ Redirigiendo a home (usuario ya autenticado)');
        return '/';
      }

      debugPrint('✅ Permitiendo: $location');
      return null; // No redirigir
    },

    // Manejo de errores
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Página no encontrada',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(state.matchedLocation),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
  );

  /// Verifica si una ruta es pública (no requiere autenticación)
  static bool _isPublicRoute(String location) {
    const publicRoutes = ['/login', '/terms', '/privacy', '/delete_account'];
    if (location.startsWith('/poi/')) return true;
    return publicRoutes.contains(location);
  }

  /// Construye un deep link hacia un POI concreto
  static Uri buildPoiDeepLink(String poiId) {
    final path = router.namedLocation(
      'poiDetail',
      pathParameters: {'poiId': poiId},
    );

    return Uri(scheme: appLinkScheme, host: appLinkHost, path: path);
  }
}
