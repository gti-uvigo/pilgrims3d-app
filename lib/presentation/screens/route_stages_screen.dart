import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/providers/connectivity_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import '../widgets/cards/poi_card.dart';
import '../widgets/route_review_bottom_sheet.dart';

class RouteStagesScreen extends StatefulWidget {
  final String routeName;
  final String routeId;

  const RouteStagesScreen({
    super.key,
    required this.routeName,
    required this.routeId,
  });

  @override
  State<RouteStagesScreen> createState() => _RouteStagesScreenState();
}

class _RouteStagesScreenState extends State<RouteStagesScreen> {
  int _currentDayIndex = 0;
  late List daysData = [];
  late List typesList = [];
  final PageController _pageController = PageController(viewportFraction: 0.9);
  Set<String> _selectedPoiTypes = {};
  List<String> _poiTypes = [];
  final Map<int, Set<int>> _flippedCards = {};
  final Map<int, Map<int, GlobalKey>> _frontCardKeys = {};
  final Map<int, Map<int, Size?>> _frontCardSizes = {};
  bool _showHint = false;
  bool _isTrackingRoute = false;
  bool _isLoggedIn = false;
  bool _speedDialOpen = false;

  @override
  void initState() {
    super.initState();
    _loadDaysData();
    _checkIfShouldShowHint();
    _checkTrackingStatus();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkTrackingStatus() async {
    // El servicio de background solo está disponible en móvil
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isTrackingRoute = false;
        });
      }
      return;
    }

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (mounted) {
      setState(() {
        _isTrackingRoute = isRunning;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (mounted) {
      setState(() {
        _isLoggedIn = FirebaseAuth.instance.currentUser != null;
      });
    }
  }

  Future<void> _toggleRouteTracking() async {
    // El servicio de background solo está disponible en móvil
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El seguimiento en segundo plano solo está disponible en dispositivos móviles',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final service = FlutterBackgroundService();

    if (_isTrackingRoute) {
      // Detener tracking
      service.invoke('stopService');

      if (mounted) {
        setState(() {
          _isTrackingRoute = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seguimiento de ruta detenido'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Guardar el nombre de la ruta en preferencias
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_route_id', widget.routeId);
      await prefs.setString(
        'active_language_id',
        Provider.of<LocaleProvider>(context, listen: false).currentLangId,
      );

      // Iniciar tracking
      await service.startService();

      if (mounted) {
        setState(() {
          _isTrackingRoute = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seguimiento de ruta iniciado: ${widget.routeName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _checkIfShouldShowHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = false; //prefs.getBool('has_seen_poi_hint') ?? false;
    if (!hasSeenHint) {
      setState(() => _showHint = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showHint = false);
          prefs.setBool('has_seen_poi_hint', true);
        }
      });
    }
  }

  Future<void> _loadDaysData() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    String langCode = localeProvider.currentLangId;
    daysData = await getDaysInformation(widget.routeId, langCode);
    typesList = await getPoisTypes(langCode);
    _poiTypes = typesList.map<String>((e) => e['id'].toString()).toList();
    if (mounted) {
      for (int i = 0; i < daysData.length; i++) {
        _frontCardKeys[i] = {};
        _frontCardSizes[i] = {};
        final pois = daysData[i]['points_of_interest'] as List;
        for (int j = 0; j < pois.length; j++) {
          _frontCardKeys[i]![j] = GlobalKey(
            debugLabel: 'frontCardKey_Day${i}_POI$j',
          );
          _frontCardSizes[i]![j] = null;
        }
      }
      setState(() {});
    }
  }

  void _goToMap() {
    // Obtener POIs solo de la etapa actual
    if (daysData.isEmpty || _currentDayIndex >= daysData.length) return;

    final currentStage = daysData[_currentDayIndex];
    final pois =
        (currentStage['points_of_interest'] as List? ?? [])
            .where(
              (poi) =>
                  _selectedPoiTypes.isEmpty ||
                  (poi['types'] != null &&
                      (poi['types'] as List).any(
                        (typeId) =>
                            _selectedPoiTypes.contains(typeId.toString()),
                      )),
            )
            .toList();

    context.push(
      '/map',
      extra: {
        'routeId': widget.routeId,
        'routeName': widget.routeName,
        'pois': pois,
      },
    );
  }

  Future<void> _openInGoogleMaps() async {
    try {
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );

      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Obtener ubicación actual
      final position = await determinePosition();
      final currentLocation = "${position.latitude},${position.longitude}";

      // 2. Obtener TODOS los POIs de TODA la ruta (no solo de la etapa actual)
      final allRoutePois = await fetchInterestPoints(
        widget.routeId,
        localeProvider.currentLangId,
      );

      if (allRoutePois.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('no_routes_available')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('🗺️ Total POIs de la ruta completa: ${allRoutePois.length}');

      // 3. Crear lista de todos los waypoints usando TODOS los POIs
      List<String> waypoints = [];
      for (int i = 0; i < allRoutePois.length; i++) {
        final poi = allRoutePois[i];
        final lat = poi['latitude'];
        final lon = poi['longitude'];
        if (lat != null && lon != null) {
          waypoints.add("$lat,$lon");
          print(
            '   POI $i: ${poi['name'] ?? poi['title'] ?? 'Sin nombre'} -> $lat,$lon',
          );
        }
      }

      if (waypoints.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('no_routes_available')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('🗺️ Total waypoints creados: ${waypoints.length}');

      // 4. Optimizar waypoints - Google Maps permite 8 waypoints intermedios + origen + destino = 9 paradas totales
      List<String> finalWaypoints = waypoints;

      if (waypoints.length > 10) {
        print(
          '🗺️ Optimizando ${waypoints.length} waypoints a 10 (máximo de Google Maps)',
        );
        finalWaypoints = [];

        // Distribuir 8 POIs uniformemente a lo largo de toda la ruta
        for (int i = 0; i < 10; i++) {
          final index = (i * (waypoints.length - 1) / 9).round().clamp(
            0,
            waypoints.length - 1,
          );
          finalWaypoints.add(waypoints[index]);
        }

        // Remover duplicados manteniendo el orden
        final uniqueWaypoints = <String>[];
        final seen = <String>{};
        for (final waypoint in finalWaypoints) {
          if (!seen.contains(waypoint)) {
            seen.add(waypoint);
            uniqueWaypoints.add(waypoint);
          }
        }
        finalWaypoints = uniqueWaypoints;

        // Asegurar que tenemos exactamente el primer y último POI
        if (finalWaypoints.first != waypoints.first) {
          finalWaypoints[0] = waypoints.first;
        }
        if (finalWaypoints.last != waypoints.last) {
          finalWaypoints[finalWaypoints.length - 1] = waypoints.last;
        }
      }

      // 5. Construir URL de Google Maps
      final origin = currentLocation;
      final destination = finalWaypoints.last;
      final waypointsStr =
          finalWaypoints.length > 1
              ? finalWaypoints.sublist(0, finalWaypoints.length - 1).join('|')
              : '';

      String googleMapsUrl;
      if (waypointsStr.isNotEmpty) {
        googleMapsUrl =
            'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypointsStr&travelmode=walking';
      } else {
        googleMapsUrl =
            'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
      }

      print(
        '🗺️ Abriendo Google Maps con ${finalWaypoints.length} POIs como waypoints',
      );
      print('🗺️ Origen: $origin');
      print('🗺️ Destino: $destination');
      print('🗺️ Waypoints intermedios: ${finalWaypoints.length - 1}');

      // 6. Abrir en Google Maps
      final uri = Uri.parse(googleMapsUrl);
      final canLaunch = await canLaunchUrl(uri);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga

        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('opening_in_google_maps')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('error_opening_maps')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error al abrir Google Maps: $e');

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga si está abierto

        final localeProvider = Provider.of<LocaleProvider>(
          context,
          listen: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localeProvider.translate('error_getting_location')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCard(int dayIndex, int poiIndex) {
    setState(() {
      _flippedCards.putIfAbsent(dayIndex, () => <int>{});
      if (_flippedCards[dayIndex]!.contains(poiIndex)) {
        _flippedCards[dayIndex]!.remove(poiIndex);
      } else {
        _flippedCards[dayIndex]!.add(poiIndex);
      }
    });
  }

  bool _isCardFlipped(int dayIndex, int poiIndex) {
    return _flippedCards[dayIndex]?.contains(poiIndex) ?? false;
  }

  void _captureFrontCardSize(int dayIndex, int poiIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verificar que existen los maps y las keys
      if (_frontCardKeys[dayIndex] == null ||
          _frontCardKeys[dayIndex]![poiIndex] == null) {
        return;
      }

      final key = _frontCardKeys[dayIndex]![poiIndex]!;
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null && renderBox.hasSize) {
        _frontCardSizes[dayIndex] ??= {};
        if (_frontCardSizes[dayIndex]![poiIndex] != renderBox.size) {
          setState(() {
            _frontCardSizes[dayIndex]![poiIndex] = renderBox.size;
          });
        }
      }
    });
  }

  void _showPoiTypeSelector() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final tempSelected = Set<String>.from(_selectedPoiTypes);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                localeProvider.translate('Filter_by_POI_type'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(
                height: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: Text(localeProvider.translate("Without_filter")),
                      value: tempSelected.isEmpty,
                      onChanged: (val) {
                        HapticService().selection();
                        context.pop(<String>{});
                      },
                    ),
                    ..._poiTypes.map((typeId) {
                      final typeObj = typesList
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (e) => e != null && e['id'].toString() == typeId,
                            orElse: () => null,
                          );
                      final typeName =
                          typeObj != null
                              ? (typeObj['text'] ?? typeId)
                              : typeId;
                      return CheckboxListTile(
                        title: Text(typeName),
                        value: tempSelected.contains(typeId),
                        onChanged: (val) {
                          HapticService().selection();
                          if (val == true) {
                            tempSelected.add(typeId);
                          } else {
                            tempSelected.remove(typeId);
                          }
                          (context as Element).markNeedsBuild();
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  HapticService().medium();
                  context.pop(tempSelected);
                },
                child: Text(localeProvider.translate("Apply_filter")),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    if (result != null) {
      setState(() => _selectedPoiTypes = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final theme = Theme.of(context);
    final isOffline =
        !kIsWeb && Provider.of<ConnectivityProvider>(context).isOffline;
    if (daysData.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          (widget.routeName).substring(0, 1).toUpperCase() +
              (widget.routeName).substring(1),
        ),
        leading: null,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double maxCardWidth = 800;
                  final double cardWidth =
                      constraints.maxWidth < maxCardWidth
                          ? constraints.maxWidth
                          : maxCardWidth;
                  final double cardHeight = constraints.maxHeight;

                  // Solo mostrar flechas en web con ancho amplio; en móvil web se arrastra
                  final double buttonSize = cardWidth * 0.5;
                  final double minWidthToShowButtons = 900;
                  final bool showArrows =
                      kIsWeb && constraints.maxWidth >= minWidthToShowButtons;
                  return Stack(
                    children: [
                      PageView.builder(
                        itemCount: daysData.length,
                        controller: _pageController,
                        physics:
                            kIsWeb && showArrows
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          HapticService().light();
                          setState(() => _currentDayIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final stage = daysData[index];
                          final pois =
                              (stage['points_of_interest'] as List)
                                  .where(
                                    (poi) =>
                                        _selectedPoiTypes.isEmpty ||
                                        (poi['types'] != null &&
                                            (poi['types'] as List).any(
                                              (typeId) => _selectedPoiTypes
                                                  .contains(typeId.toString()),
                                            )),
                                  )
                                  .toList();
                          return Center(
                            child: SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                elevation: 4,
                                shadowColor: theme.shadowColor.withOpacity(0.2),
                                clipBehavior: Clip.antiAlias,
                                color: theme.cardTheme.color,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12.0),
                                  itemCount: pois.length + 1,
                                  itemBuilder: (context, poiIndex) {
                                    if (poiIndex == 0) {
                                      return Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              '${localeProvider.translate('stage')} ${daysData[_currentDayIndex]['day']}',
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              daysData[_currentDayIndex]['name'] ??
                                                  '',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                          ],
                                        ),
                                      );
                                    } else {
                                      final poi = pois[poiIndex - 1];
                                      _captureFrontCardSize(
                                        index,
                                        poiIndex - 1,
                                      );

                                      // Verificar que los maps tienen los keys necesarios
                                      final frontCardSize =
                                          _frontCardSizes[index]?[poiIndex - 1];
                                      final frontCardKey =
                                          _frontCardKeys[index]?[poiIndex - 1];

                                      if (frontCardKey == null) {
                                        // Si no existe la key, crearla
                                        _frontCardKeys[index] ??= {};
                                        _frontCardKeys[index]![poiIndex -
                                            1] = GlobalKey(
                                          debugLabel:
                                              'frontCardKey_Day${index}_POI${poiIndex - 1}',
                                        );
                                      }

                                      return PoiCard(
                                        poi: poi,
                                        localeProvider: localeProvider,
                                        theme: theme,
                                        dayIndex: index,
                                        poiIndex: poiIndex - 1,
                                        frontCardSize: frontCardSize,
                                        fixedCardHeight: cardHeight / 2.5,
                                        isFlipped: _isCardFlipped(
                                          index,
                                          poiIndex - 1,
                                        ),
                                        onFlip:
                                            () => _toggleCard(
                                              index,
                                              poiIndex - 1,
                                            ),
                                        showHint: _showHint,
                                        frontCardKey:
                                            _frontCardKeys[index]![poiIndex -
                                                1]!,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (showArrows) ...[
                        if (_currentDayIndex > 0)
                          Positioned(
                            left:
                                (constraints.maxWidth - cardWidth) / 2.5 -
                                buttonSize / 2,
                            top: cardHeight / 2 - buttonSize / 2,
                            child: GestureDetector(
                              onTap: () async {
                                if (_currentDayIndex > 0) {
                                  await HapticService().navigation();
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                              child: Container(
                                width: buttonSize,
                                height: buttonSize,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  color: theme.colorScheme.primary,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                        if (_currentDayIndex < daysData.length - 1)
                          Positioned(
                            right:
                                (constraints.maxWidth - cardWidth) / 2.5 -
                                buttonSize / 2,
                            top: cardHeight / 2 - buttonSize / 2,
                            child: GestureDetector(
                              onTap: () async {
                                if (_currentDayIndex < daysData.length - 1) {
                                  await HapticService().navigation();
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                              child: Container(
                                width: buttonSize,
                                height: buttonSize,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: theme.colorScheme.primary,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                daysData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentDayIndex == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _currentDayIndex == index
                            ? theme.colorScheme.primary
                            : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: _buildSpeedDial(
        context,
        localeProvider,
        theme,
        isOffline,
      ),
    );
  }

  Widget _buildSpeedDial(
    BuildContext context,
    LocaleProvider localeProvider,
    ThemeData theme,
    bool isOffline,
  ) {
    final cs = theme.colorScheme;

    Widget dialItem({
      required String heroTag,
      required IconData icon,
      required Color bg,
      required Color fg,
      required String label,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: heroTag,
              backgroundColor: bg,
              foregroundColor: fg,
              elevation: 2,
              onPressed: () {
                setState(() => _speedDialOpen = false);
                onTap();
              },
              child: Icon(icon),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Overlay para cerrar al tocar fuera
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child:
              _speedDialOpen
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Reseñas
                      dialItem(
                        heroTag: 'reviewRoute',
                        icon: Icons.rate_review_rounded,
                        bg: cs.primaryContainer,
                        fg: cs.onPrimaryContainer,
                        label: localeProvider.translate('rate_route'),
                        onTap:
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (_) => RouteReviewBottomSheet(
                                    routeId: widget.routeId,
                                    routeName: widget.routeName,
                                    isLoggedIn: _isLoggedIn,
                                  ),
                            ),
                      ),
                      // Tracking (solo móvil + logueado + online)
                      if (!kIsWeb && _isLoggedIn && !isOffline)
                        dialItem(
                          heroTag: 'trackRoute',
                          icon:
                              _isTrackingRoute ? Icons.stop : Icons.play_arrow,
                          bg:
                              _isTrackingRoute
                                  ? Colors.red.shade700
                                  : cs.primary,
                          fg: Colors.white,
                          label:
                              _isTrackingRoute
                                  ? localeProvider.translate('stop')
                                  : localeProvider.translate('start'),
                          onTap: _toggleRouteTracking,
                        ),
                      // Filtrar POIs
                      dialItem(
                        heroTag: 'filterPoiType',
                        icon: Icons.filter_alt_rounded,
                        bg: cs.secondary,
                        fg: cs.onSecondary,
                        label: localeProvider.translate('Filter_by_POI_type'),
                        onTap: _showPoiTypeSelector,
                      ),
                      // Google Maps
                      dialItem(
                        heroTag: 'openGoogleMaps',
                        icon: Icons.directions_rounded,
                        bg: Colors.blue.shade600,
                        fg: Colors.white,
                        label: 'Google Maps',
                        onTap: _openInGoogleMaps,
                      ),
                      // Mapa interno
                      dialItem(
                        heroTag: 'goToMap',
                        icon: Icons.map_outlined,
                        bg: cs.secondaryContainer,
                        fg: cs.onSecondaryContainer,
                        label: localeProvider.translate('view_route'),
                        onTap: _goToMap,
                      ),
                      const SizedBox(height: 4),
                    ],
                  )
                  : const SizedBox.shrink(),
        ),
        // Botón principal
        FloatingActionButton(
          heroTag: 'speedDialMain',
          backgroundColor: _speedDialOpen ? cs.error : cs.primary,
          foregroundColor: _speedDialOpen ? cs.onError : cs.onPrimary,
          onPressed: () {
            HapticService().light();
            setState(() => _speedDialOpen = !_speedDialOpen);
          },
          child: AnimatedRotation(
            turns: _speedDialOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
