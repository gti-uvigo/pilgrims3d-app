import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pilgrims_3d/presentation/providers/route_provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/home_drawer.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/core/config/env.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with TickerProviderStateMixin {
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
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.translate('events')),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      drawer: const HomeDrawer(),
      body: _buildBody(routeProvider, localeProvider),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_button',
        backgroundColor: Colors.amber,
        onPressed: () {
          HapticService().medium();
          context.go('/');
        },
        tooltip: localeProvider.translate('home'),
        child: const Icon(Icons.home, color: Colors.white),
      ),
    );
  }

  _buildBody(RouteProvider routeProvider, LocaleProvider localeProvider) {
    if (routeProvider.isLoading || _tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<dynamic>(
      future: api.getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  localeProvider.translate('error_loading_events'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final events = snapshot.data as List<dynamic>? ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  localeProvider.translate('no_events_available'),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCard(event: event, localeProvider: localeProvider);
          },
        );
      },
    );
  }
}

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final LocaleProvider localeProvider;

  const EventCard({
    super.key,
    required this.event,
    required this.localeProvider,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  List<dynamic>? _routes;
  bool _isLoadingRoutes = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpand() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();

      if (_routes == null) {
        final routesIds = widget.event['routes_ids'] as List<dynamic>?;
        if (routesIds != null && routesIds.isNotEmpty) {
          setState(() {
            _isLoadingRoutes = true;
          });

          try {
            // Obtener información de cada ruta usando los POIs
            final List<dynamic> routes = [];
            for (var routeId in routesIds) {
              debugPrint('Obteniendo información para ruta: $routeId');
              final pois = await api.fetchInterestPoints(
                routeId.toString(),
                widget.localeProvider.currentLangId,
              );

              if (pois.isNotEmpty) {
                debugPrint('📋 Primer POI de la ruta: ${pois[0]}');

                // Crear un objeto con la información básica de la ruta
                final routeInfo = {
                  'route_id': routeId,
                  'route_name':
                      pois[0]['route_name'] ??
                      pois[0]['name'] ??
                      pois[0]['title'] ??
                      'Ruta sin nombre',
                  'image_id': pois[0]['image_id'],
                  'pois_count': pois.length,
                };
                routes.add(routeInfo);
                debugPrint(
                  '✅ Ruta encontrada: ${routeInfo['route_name']} con ${pois.length} POIs',
                );
              } else {
                debugPrint('⚠️ No se encontraron POIs para la ruta $routeId');
              }
            }

            setState(() {
              _routes = routes;
              _isLoadingRoutes = false;
            });
            debugPrint('Total de rutas cargadas: ${routes.length}');
          } catch (e) {
            debugPrint('❌ Error cargando rutas: $e');
            setState(() {
              _isLoadingRoutes = false;
            });
          }
        }
      }
    } else {
      _animationController.reverse();
    }

    HapticService().light();
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        widget.event['name'] ?? widget.localeProvider.translate('no_title');
    final String description = widget.event['description'] ?? '';
    final String? imageId = widget.event['image_id'];
    final String? imageUrl =
        imageId != null ? '$baseUrl/images/$imageId' : null;
    final String? date = widget.event['date'];
    final String? duration = widget.event['duration'];
    final String? location = widget.event['location'];
    final String? url = widget.event['url'];
    final List<dynamic>? routesIds =
        widget.event['routes_ids'] as List<dynamic>?;
    final bool hasRoutes = routesIds != null && routesIds.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xffa7c686),
                              const Color(0xff8aac6b),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                // Gradiente en la parte inferior de la imagen
                // Scrim eased: concentrado en el 60% inferior con curva suave
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.60,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xBF000000), // 0.75
                                Color(0x80000000), // 0.50
                                Color(0x45000000), // 0.27
                                Color(0x1A000000), // 0.10
                                Color(0x05000000), // 0.02
                                Color(0x00000000), // 0.00
                              ],
                              stops: [0.0, 0.12, 0.28, 0.50, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge de duración si existe
                if (duration != null && duration.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          InkWell(
            onTap: hasRoutes ? _toggleExpand : null,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (hasRoutes)
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xffa7c686).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.expand_more,
                              color: Color(0xff6b8a50),
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (date != null && date.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffa7c686).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xff6b8a50),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xff6b8a50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: Colors.red[400],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                      maxLines: _isExpanded ? null : 3,
                      overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ],
                  if (url != null && url.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffa7c686), Color(0xff8aac6b)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffa7c686).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticService().light();
                            debugPrint('Opening URL: $url');
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_new,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.localeProvider.translate('more_info'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                if (hasRoutes) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.grey[300]!,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.route,
                              color: Color(0xff6b8a50),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.localeProvider.translate(
                                'associated_routes',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff6b8a50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingRoutes)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_routes != null && _routes!.isNotEmpty)
                          ..._routes!.asMap().entries.map((entry) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                milliseconds: 300 + (entry.key * 100),
                              ),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: _buildRouteItem(entry.value, context),
                            );
                          })
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.localeProvider.translate(
                                      'no_routes_available',
                                    ),
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem(Map<String, dynamic> route, BuildContext context) {
    final String routeName = route['route_name'] ?? 'Sin nombre';
    final String? routeImageId = route['image_id'];
    final String? routeImageUrl =
        routeImageId != null ? '$baseUrl/images/$routeImageId' : null;
    final String routeId = route['route_id']?.toString() ?? '';
    final int poisCount = route['pois_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xffa7c686).withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffa7c686).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService().medium();
            if (routeId.isNotEmpty) {
              context.push(
                '/route',
                extra: {'routeId': routeId, 'routeName': routeName},
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'route_image_$routeId',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          routeImageUrl != null
                              ? Image.network(
                                routeImageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 70,
                                    height: 70,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xffa7c686),
                                          Color(0xff8aac6b),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              )
                              : Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xffa7c686),
                                      Color(0xff8aac6b),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.route,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffa7c686).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 14,
                              color: Color(0xff6b8a50),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$poisCount POIs',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff6b8a50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffa7c686).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xff6b8a50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
