import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:provider/provider.dart';

import 'package:pilgrims_3d/presentation/providers/route_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/home_drawer.dart';
import 'package:pilgrims_3d/presentation/widgets/route_list_view.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';

// El StatefulWidget ahora solo gestiona el TabController, que es un estado de UI local.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Actívalo desde el flujo de login para que HomeScreen muestre el banner
  /// una sola vez al llegar a la pantalla principal.
  static bool pendingRateCheck = false;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeProvider = context.watch<RouteProvider>();
    if (!routeProvider.isLoading && routeProvider.error.isEmpty) {
      if (_tabController == null ||
          _tabController!.length != routeProvider.routeTypes.length) {
        _tabController = TabController(
          length: routeProvider.routeTypes.length,
          vsync: this,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // En Android siempre comprobamos (sesión ya iniciada o recién logado).
    // En el resto de plataformas solo si viene del flujo de login.
    final bool isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final bool isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isAndroid || isIos || HomeScreen.pendingRateCheck) {
      HomeScreen.pendingRateCheck = false;
      _checkRateNotification();
    }
  }

  Future<void> _checkRateNotification() async {
    final show = await api.check_show_rate_notification();
    if (!show || !mounted) return;
    // Pequeño delay para que la UI esté completamente renderizada
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _showRateBanner();
  }

  void _showRateBanner() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _RateUsBanner(
        onTap: () {
          entry.remove();
          context.push('/survey');
        },
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await determinePosition();
      setState(() {});
      if (!kIsWeb) {
        await api.updateUserCoords(position.latitude, position.longitude);
      }
    } catch (e) {
      print('Error al obtener la ubicación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // La UI consume datos de los providers, pero no sabe cómo se obtienen.
    final routeProvider = context.watch<RouteProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.translate('routes')),
        bottom:
            (routeProvider.isLoading || _tabController == null)
                ? const PreferredSize(
                  preferredSize: Size.fromHeight(48.0),
                  child: LinearProgressIndicator(),
                )
                : TabBar(
                  controller: _tabController,
                  // Distribuye las pestañas en todo el ancho (comportamiento similar a spaceBetween)
                  isScrollable: false,
                  indicatorColor: const Color(0xffa7c686),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xffa7c686),
                  labelPadding: EdgeInsets.zero,
                  tabs:
                      routeProvider.routeTypes.map<Tab>((route) {
                        final name = route['name'] as String;
                        return Tab(
                          text:
                              name.substring(0, 1).toUpperCase() +
                              name.substring(1),
                        );
                      }).toList(),
                ),
      ),
      drawer: const HomeDrawer(),
      body: _buildBody(routeProvider, localeProvider),
      floatingActionButton:
          (routeProvider.isLoading || _tabController == null)
              ? null
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'nearby_routes_button',
                    backgroundColor: Colors.green[700],
                    onPressed: () {
                      HapticService().medium();
                      context.push(
                        '/nearbyRoutesMap',
                        extra: {
                          'languageId': localeProvider.currentLangId,
                          'distanceKm': 2.0,
                        },
                      );
                    },
                    tooltip: 'Rutas cercanas (2 km)',
                    child: const Icon(Icons.near_me, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'map_button',
                    onPressed: () {
                      HapticService().medium();
                      final currentIndex = _tabController!.index;
                      final currentRoute =
                          routeProvider.routeTypes[currentIndex];
                      context.push(
                        '/allRoutesMap',
                        extra: {
                          'routeType': currentRoute['id'],
                          'languageId': localeProvider.currentLangId,
                        },
                      );
                    },
                    child: const Icon(Icons.map),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'events_button',
                    backgroundColor: Colors.amber,
                    onPressed: () {
                      HapticService().medium();
                      context.push('/events');
                    },
                    child: const Icon(Icons.calendar_month, color: Colors.white),
                  ),
                ],
              ),
    );
  }

  Widget _buildBody(
    RouteProvider routeProvider,
    LocaleProvider localeProvider,
  ) {
    if (routeProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (routeProvider.error.isNotEmpty) {
      return Center(
        child: Text(
          routeProvider.error,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_tabController == null) {
      return Center(child: Text(localeProvider.translate('initializing_tabs')));
    }

    return TabBarView(
      controller: _tabController,
      children:
          routeProvider.routeTypes.map<Widget>((route) {
            return FutureBuilder<List<dynamic>>(
              future: api.getCardInformation(
                route['id'],
                route["subtypes"][0]["name"],
                localeProvider.currentLangId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '${localeProvider.translate('Error')}: ${snapshot.error}',
                    ),
                  );
                }
                return RouteListView(
                  ruta: route['id'],
                  cards: snapshot.data ?? [],
                  onCardTap:
                      (card) => context.push(
                        '/route',
                        extra: {
                          'routeName': card['title'],
                          'routeId': card['route_id'],
                        },
                      ),
                );
              },
            );
          }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner de valoración
// ---------------------------------------------------------------------------

class _RateUsBanner extends StatefulWidget {
  const _RateUsBanner({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_RateUsBanner> createState() => _RateUsBannerState();
}

class _RateUsBannerState extends State<_RateUsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.watch<LocaleProvider>();
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rate_rounded,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.translate('rate_us_banner_title'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.translate('rate_us_banner_body'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.onTap,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(loc.translate('rate_us_rate_btn')),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  onPressed: _dismiss,
                  tooltip: loc.translate('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
