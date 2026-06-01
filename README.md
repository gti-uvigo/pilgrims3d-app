# Rurallure — Estructura del proyecto y guía rápida

Proyecto Flutter con soporte para AR, mapas, Firebase y visualización 3D. Este README explica dónde va cada cosa y los archivos/clases principales.

## Resúmen rápido
- Código fuente principal: [lib/](lib/)  
- Configuración de dependencias: [pubspec.yaml](pubspec.yaml)  
- Build artefacts y avisos de licencias: [build/](build/) — por ejemplo [build/web/assets/NOTICES](build/web/assets/NOTICES)  
- Configuración Firebase Android: [android/app/google-services.json](android/app/google-services.json)  
- PWA / Web manifest: [web/manifest.json](web/manifest.json)

## Archivos de entrada / ejecución
- Punto de entrada de la app: [lib/main.dart](lib/main.dart) — contiene la clase principal [`MyApp`](lib/main.dart) y la inicialización de servicios (Firebase, Haptic, Providers).
- Dependencias y versión: [pubspec.yaml](pubspec.yaml)

## Estructura principal (carpetas clave)
- lib/ — Código fuente
  - lib/main.dart — Inicialización y `runApp`.
  - lib/core/  
    - lib/core/config/env.dart — variables de entorno y configuración pública (ej. [`baseUrl`](lib/core/config/env.dart)).  
    - lib/core/config/routes.dart — rutas y configuración de navegación (GoRouter) ([lib/core/config/routes.dart](lib/core/config/routes.dart)).  
    - lib/core/config/theme.dart — tema de la app ([lib/core/config/theme.dart](lib/core/config/theme.dart)).
  - lib/services/  
    - lib/services/haptic/haptic_service.dart — servicio central de vibraciones ([`HapticService`](lib/services/haptic/haptic_service.dart)).  
    - lib/services/translations/translations.dart — mapa de traducciones y localizaciones ([`translations`](lib/services/translations/translations.dart)).  
    - lib/services/firebase/ — inicialización de Firebase y FCM.
  - lib/data/ — repositorios y acceso a datos (ej. `data/repositories/auth_repository.dart`).
  - lib/presentation/ — UI y widgets  
    - lib/presentation/screens/  
      - [lib/presentation/screens/create_poi_screen.dart](lib/presentation/screens/create_poi_screen.dart) — pantalla para crear POIs (`CreatePOIScreen`)  
      - [lib/presentation/screens/model3d_screen.dart](lib/presentation/screens/model3d_screen.dart) — visor 3D (`ModelViewerScreen`)  
      - [lib/presentation/screens/terms_screen.dart](lib/presentation/screens/terms_screen.dart) — términos y condiciones (`TermsAndConditionsScreen`)  
      - [lib/presentation/screens/about_screen.dart](lib/presentation/screens/about_screen.dart) — pantalla “About” y modelo `_Person`  
    - lib/presentation/widgets/ — widgets reutilizables (ej. [lib/presentation/widgets/cards/poi_card_simple.dart](lib/presentation/widgets/cards/poi_card_simple.dart) usa `HapticService`).
- android/, ios/, linux/, macos/, windows/ — plataformas nativas y configuración específica.
- web/ — archivos para versión web (p. ej. [web/manifest.json](web/manifest.json)).
- build/ — artefactos generados (no versionar). Contiene avisos de licencias: [build/web/assets/NOTICES](build/web/assets/NOTICES).

## Archivos de configuración y utilidades
- `.firebaserc` — proyecto Firebase por defecto.
- `run_flutter_clean.sh`, `rebuild_ios.sh` — scripts útiles para limpiar/compilar.
- `HAPTIC_FEEDBACK.md` — documentación interna sobre el servicio háptico ([HAPTIC_FEEDBACK.md](HAPTIC_FEEDBACK.md)).

## Traducciones / Localización
- Todas las cadenas traducidas están en [lib/services/translations/translations.dart](lib/services/translations/translations.dart) en el mapa [`translations`](lib/services/translations/translations.dart). El `LocaleProvider` en `lib/presentation/providers/locale_provider.dart` gestiona la selección de idioma.

## Servicios y dónde inicializarlos
- Firebase: inicializado en [lib/main.dart](lib/main.dart) (llamada a servicios en `main`). Archivos específicos:
  - Android: [android/app/google-services.json](android/app/google-services.json)
  - (iOS) `GoogleService-Info.plist` debe ir en `ios/Runner/`
- Haptics: servicio central en [lib/services/haptic/haptic_service.dart](lib/services/haptic/haptic_service.dart) — inicializar en `main` con `await HapticService().initialize();` y usar `HapticService().medium()` etc.
- API base: la URL base está en [lib/core/config/env.dart](lib/core/config/env.dart) como [`baseUrl`](lib/core/config/env.dart).

## Assets y recursos
# Rurallure — Estructura del proyecto y guía completa

Proyecto Flutter con soporte para AR, mapas, Firebase y visualización 3D. Este README combina un resumen rápido con una explicación detallada archivo por archivo de la carpeta `lib/` (qué hace cada fichero y por qué está ahí).

## Resumen rápido
- Código fuente principal: `lib/`
- Configuración de dependencias: `pubspec.yaml`
- Artefactos de build: `build/` (no versionar). Ejemplo: `build/web/assets/NOTICES`
- Configuración Firebase Android: `android/app/google-services.json`
- PWA / Web manifest: `web/manifest.json`

## Cómo ejecutar (rápido)
1. Instala dependencias:

```bash
flutter pub get
```

2. Ejecuta la app en un dispositivo/emulador:

```bash
flutter run
```

Si necesitas limpiar:

```bash
./run_flutter_clean.sh
```

---

## Estructura principal y propósito de carpetas

- `lib/` — Código fuente principal (ver detalle más abajo).
- `android/`, `ios/`, `linux/`, `macos/`, `windows/` — código y configuración nativa por plataforma.
- `web/` — recursos para la versión web (manifest, icons, index.html).
- `build/` — artefactos generados por Flutter (no commitear).

---

## Archivo de entrada

- `lib/main.dart`
  - Qué hace: punto de entrada. Inicializa Flutter, Firebase (`FirebaseService.initialize()`), el servicio háptico (`HapticService().initialize()`), y arranca la app con `MultiProvider` (inyecta `LocaleProvider`, `ThemeProvider`, `AuthRepository`, `AuthProvider`, `RouteProvider`). Usa `MaterialApp.router` con `AppRouter`.
  - Por qué está aquí: centraliza inicializaciones y la inyección de dependencias.

---

## `lib/core/` — configuración y utilidades centrales

- `lib/core/config/env.dart`
  - Contiene constantes y variables globales: `baseUrl` del backend, claves de Firebase Web (API key, project id), timeouts y variables mutables como `notificationsToken`, `idToken`, `email`.
  - Uso: valores de configuración que el resto de servicios y API consumen.

- `lib/core/config/routes.dart`
  - Define `AppRouter` usando `go_router` y la `navigatorKey` global. Declara rutas públicas y privadas, recibe `state.extra` para pasar parámetros entre pantallas y aplica redirección basada en el estado de autenticación (`FirebaseAuth.instance.currentUser`).

- `lib/core/config/theme.dart`
  - Define `AppTheme` con `lightTheme` y `darkTheme` (colores, estilos de AppBar, botones, inputs, etc.). Incluye utilidades como `ThemeNotifier`.

- `lib/core/errors/exceptions.dart`
  - Define excepciones de dominio: `AppException` y subclases (`AuthException`, `NetworkException`, `ServerException`, `CacheException`, `ValidationException`).

- `lib/core/utils/crypto.dart`
  - `getEmailSha256(email)`: utilidad para obtener SHA-256 de un email (utilizada para generar `idToken` derivado).

- `lib/core/utils/location_helper.dart`
  - `determinePosition()`: envoltorio de `geolocator` para solicitar permisos y devolver la posición actual o lanzar excepciones legibles.

---

## `lib/services/` — integraciones externas y lógica de plataforma

- `lib/services/firebase/firebase_service.dart`
  - Inicializa Firebase en web y nativo. Proporciona `FirebaseService.initialize()` y getters para la instancia.

- `lib/services/firebase/fcm_service.dart`
  - Singleton para Firebase Cloud Messaging (permiso de notificaciones, obtención/refresh del token, listeners `onMessage` y `onMessageOpenedApp`). Muestra diálogos desde el `navigatorKey` y guarda `notificationsToken` en `env.dart`.

- `lib/services/firebase/auth_service.dart`
  - Lógica detallada de autenticación: login/registro con email, Google Sign-In, manejo de ID tokens, envío de email de recuperación, sign out, delete account y conversión de errores Firebase a `AuthException`.

- `lib/services/api/api_service.dart`
  - Conjunto de funciones que llaman al backend REST (`baseUrl`) con reintentos y timeouts (`makeRequestWithRetry`). Funciones principales: `getDaysInformation`, `getCardInformation`, `fetchRouteCoordinates`, `fetchInterestPoints`, `getLanguages`, `getRouteTypes`, `fetchImage`, `moreInfoPois`, `getPoisTypes`, `getAllRoutesByRouteType`, `registerUser`, `updateUserCoords`, `send_notification_sos`, `create_poi`, `get_pois_by_user_email`, etc.
  - Uso: centralizar llamadas HTTP y lógica de reintentos.

- `lib/services/haptic/haptic_service.dart`
  - Servicio único que encapsula `HapticFeedback` y `vibration`. Métodos: `initialize()`, `light()`, `medium()`, `heavy()`, `success()`, `error()`, `warning()`, `notification()`, `custom()`, `cancel()`.

- `lib/services/translations/translations.dart`
  - Mapa `translations` con claves de idioma (UUID-like) y pares `key -> texto` para múltiples idiomas (es, en, fr, de, it, pt, ca, gl, ...). Utilizado por `LocaleProvider`.

---

## `lib/data/` — repositorios

- `lib/data/repositories/auth_repository.dart`
  - Abstracción sobre `FirebaseAuth` y proveedores externos (Google, Apple). Métodos: `signInWithEmailAndPassword`, `signUpWithEmailAndPassword`, `sendPasswordResetEmail`, `signInWithGoogle`, `signInWithApple`, `signOut`.

- `lib/data/repositories/location_repository.dart`
  - Abstracción sobre `Geolocator` para obtener la ubicación del dispositivo y manejar permisos.

---

## `lib/presentation/providers/` — estado y lógica para la UI

- `lib/presentation/providers/auth_provider.dart`
  - `AuthProvider` (ChangeNotifier) que medía entre la UI y `AuthRepository`. Realiza flujos comunes post-login (actualiza `env.idToken` con SHA-256 del email y registra usuario contra el backend con `api.registerUser()`). Devuelve mensajes legibles para la UI.

- `lib/presentation/providers/locale_provider.dart`
  - `LocaleProvider` (ChangeNotifier) que guarda la preferencia de idioma en `SharedPreferences`, expone `translate(key, args)` usando `translations`.

- `lib/presentation/providers/theme_provider.dart`
  - `ThemeProvider` (ChangeNotifier) que guarda la preferencia de tema (light/dark) en `SharedPreferences`.

- `lib/presentation/providers/route_provider.dart`
  - `RouteProvider` (ChangeNotifier) que carga tipos de ruta desde la API (`api.getRouteTypes()`), manteniendo `_isLoading`, `_error` y `_routeTypes`.

---

## `lib/presentation/widgets/` — componentes reutilizables

- `home_drawer.dart` — Drawer lateral con navegación y opciones de la app.
- `route_list_view.dart` — Lista de tarjetas de rutas (usada en `HomeScreen`).
- `cards/poi_card.dart`, `cards/poi_card_simple.dart` — componentes para mostrar POIs (tarjetas con flip, preview y acciones). `PoiCardSimple` se usa en `MyPoisScreen`.
- `map/*` — componentes relacionados con mapas: marcadores (current location, route endpoints, interest points), botones flotantes, mapas personalizados.
- `languages_dropdown.dart` — dropdown para cambiar idioma.
- `sponsors_logos.dart` — logos de patrocinadores (usado en `LoginScreen`).

---

## `lib/presentation/screens/` — pantallas principales

- `home_screen.dart`
  - Pantalla principal con `TabBar` que muestra tipos de rutas (usa `RouteProvider`). Cada pestaña hace consultas a la API y muestra `RouteListView`. Actualiza las coordenadas del usuario y permite abrir mapas por tipo de ruta.

- `login_screen.dart`
  - Pantalla de autenticación usando `flutter_login`. Integra login/registro por email, Google y Apple. Usa `AuthProvider`.

- `settings_screen.dart` (inferido)
  - Ajustes de usuario: tema, idioma, notificaciones, etc.

- `all_routes_map_screen.dart` (inferido)
  - Mapa con todas las rutas para un tipo dado (usa `getAllRoutesByRouteType`).

- `about_screen.dart`
  - Información del proyecto, créditos y enlaces.

- `route_stages_screen.dart` (inferido)
  - Detalle de las etapas/días de una ruta (`getDaysInformation`).

- `my_pois_screen.dart`
  - Lista de POIs del usuario (`get_pois_by_user_email`), muestra tarjetas y modales con más información.

- `ar_screen.dart`
  - Pantalla AR basada en `ar_flutter_plugin_2`. Gestiona anchors y nodes, permite colocar modelos `.glb` en el mundo real.

- `model3d_screen.dart`
  - Visor 3D con `model_viewer_plus` para mostrar `.glb` remotos.

- `create_poi_screen.dart`
  - Formulario para crear POIs: picker de imagen (`image_picker`), obtención de coordenadas (`determinePosition()`), y envío a `create_poi` del backend.

- `terms_screen.dart`, `delete_account_screen.dart`, `one_route_map_screen.dart`
  - Pantallas de soporte (términos, eliminar cuenta, vista de una ruta en el mapa).

---

## Interacciones importantes y flujo de datos

- `main.dart` configura providers y servicios. `AuthRepository` es inyectado y usado por `AuthProvider`.
- `AppRouter` controla la navegación y protege rutas privadas con Firebase Auth.
- `api_service.dart` realiza llamadas REST que consumen las pantallas y los providers.
- `FirebaseService`, `FCMService`, `AuthService` encapsulan integraciones con Firebase (inicialización, notificaciones, auth).
- `LocaleProvider` y `translations` proporcionan i18n; `HapticService` centraliza el feedback háptico.

---

## Consideraciones y casos límite

- Autenticación: las redirecciones del router dependen de `FirebaseAuth.instance.currentUser` — pueden existir condiciones de carrera si el estado del usuario no está listo enseguida. La app inicializa Firebase en `main`, lo que reduce este riesgo.
- Localización: si `determinePosition()` arroja errores por permisos denegados, las pantallas deben manejarlo (ya hay manejo de errores en `HomeScreen` y `CreatePOIScreen`).
- Peticiones HTTP: `api_service` implementa reintentos y timeouts; aun así la UI muestra estados de error y loaders.
- Seguridad: `lib/core/config/env.dart` contiene claves de Firebase para web y variables públicas. No introducir secretos privados en el repo.

---
