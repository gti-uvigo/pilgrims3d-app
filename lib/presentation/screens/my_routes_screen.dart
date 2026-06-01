import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/providers/offline_provider.dart';
import 'package:pilgrims_3d/presentation/providers/connectivity_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  bool _isLoading = true;
  List<dynamic> _myRoutes = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMyRoutes();
  }

  Future<void> _loadMyRoutes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );
      final routes = await api.getMyRoutes(localeProvider.currentLangId);

      if (mounted) {
        setState(() {
          _myRoutes = routes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.translate('my_routes')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: localeProvider.translate('create_own_route'),
            onPressed: () => context.push('/create_route'),
          ),
        ],
      ),
      body: _buildBody(localeProvider, theme),
    );
  }

  Widget _buildBody(LocaleProvider localeProvider, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              localeProvider.translate('error_loading_routes'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMyRoutes,
              icon: const Icon(Icons.refresh),
              label: Text(localeProvider.translate('retry')),
            ),
          ],
        ),
      );
    }

    if (_myRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              localeProvider.translate('no_routes_created'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                localeProvider.translate('create_your_first_route'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/create_route'),
              icon: const Icon(Icons.add),
              label: Text(localeProvider.translate('create_route')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyRoutes,
      child: _buildRoutesList(localeProvider, theme),
    );
  }

  Widget _buildRoutesList(LocaleProvider localeProvider, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 2 : 1;
    double childAspectRatio = (screenWidth * 0.00126).clamp(1.5, 2.5);
    double padding = screenWidth * 0.101;

    return GridView.builder(
      padding: EdgeInsets.only(
        left: padding,
        right: padding,
        top: 10,
        bottom: 10,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _myRoutes.length,
      itemBuilder: (context, index) {
        var route = _myRoutes[index];
        return _buildRouteCard(route, localeProvider, theme);
      },
    );
  }

  Widget _buildRouteCard(
    Map<String, dynamic> route,
    LocaleProvider localeProvider,
    ThemeData theme,
  ) {
    final OfflineProvider? offlineProvider =
        kIsWeb ? null : Provider.of<OfflineProvider>(context, listen: false);
    final isOffline =
        !kIsWeb && Provider.of<ConnectivityProvider>(context).isOffline;
    final isDownloaded =
        !kIsWeb &&
        offlineProvider!.isRouteDownloaded(
          route['route_id'].toString(),
          localeProvider.currentLangId,
        );
    final isAvailable = !isOffline || isDownloaded;

    return AbsorbPointer(
      absorbing: !isAvailable,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: () {
            HapticService().light();
            context.push(
              '/route',
              extra: {
                'routeName': route['title'] ?? route['name'],
                'routeId': route['route_id'],
              },
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OfflineCachedImage(
                    imageUrl: "$baseUrl/images/${route["image_id"]}",
                    imageId: route["image_id"].toString(),
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) =>
                            Image.asset('images/aragon.jpg', fit: BoxFit.cover),
                  ),
                  // Overlay para rutas no disponibles (indica indisponibilidad con oscuridad total)
                  if (!isAvailable)
                    Container(color: Colors.black.withOpacity(0.7)),
                  // Scrim eased: concentrado en el 55% inferior, para rutas disponibles
                  if (isAvailable)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 1,
                            heightFactor: 0.55,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xBF000000), // 0.75
                                    Color(0x80000000), // 0.50
                                    Color(0x45000000), // 0.27
                                    Color(0x1A000000), // 0.10
                                    Color(0x05000000), // 0.02
                                    Color(0x00000000), // 0.00
                                  ],
                                  stops: [0.0, 0.12, 0.28, 0.50, 0.75, 1.0],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Stack(
                    children: [
                      // Título y subtítulo en la parte inferior — frosted glass
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.black.withOpacity(0.38),
                              child: ListTile(
                                title: Text(
                                  route["title"] ?? '',
                                  style: TextStyle(
                                    color:
                                        isAvailable
                                            ? Colors.white
                                            : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 12.0,
                                        color: Colors.black87,
                                        offset: Offset(0, 2),
                                      ),
                                      Shadow(
                                        blurRadius: 4.0,
                                        color: Colors.black54,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                                subtitle: Text(
                                  "${localeProvider.translate('distance')}: ${route["distance"] ?? ''} km",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8.0,
                                        color: Colors.black87,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing:
                                    !isAvailable
                                        ? const Icon(
                                          Icons.cloud_off,
                                          color: Colors.redAccent,
                                          size: 24,
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Botón de descarga en la esquina superior derecha
                      if (!kIsWeb && isAvailable)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticService().medium();
                                _downloadRoute(
                                  context,
                                  route['route_id'].toString(),
                                  route['title'].toString(),
                                  localeProvider,
                                  offlineProvider!,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  isDownloaded
                                      ? Icons.check_circle
                                      : Icons.download_for_offline_outlined,
                                  color:
                                      isDownloaded
                                          ? Colors.greenAccent
                                          : Colors.white70,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Botón de eliminar discreto en la esquina superior izquierda
                      if (isAvailable)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticService().medium();
                                _confirmDeleteRoute(route, localeProvider);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadRoute(
    BuildContext context,
    String routeId,
    String routeName,
    LocaleProvider localeProvider,
    OfflineProvider offlineProvider,
  ) async {
    // Verificar si ya está descargada
    final isDownloaded = offlineProvider.isRouteDownloaded(
      routeId,
      localeProvider.currentLangId,
    );

    if (isDownloaded) {
      // Mostrar diálogo para eliminar descarga
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(localeProvider.translate('route_downloaded')),
              content: Text(
                localeProvider.translate('delete_downloaded_route_question'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localeProvider.translate('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localeProvider.translate('delete')),
                ),
              ],
            ),
      );

      if (shouldDelete == true && context.mounted) {
        final success = await offlineProvider.deleteDownloadedRoute(
          routeId,
          localeProvider.currentLangId,
        );
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localeProvider.translate('route_deleted'))),
          );
        }
      }
    } else {
      // Descargar ruta
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => Consumer<OfflineProvider>(
              builder: (context, offlineProvider, child) {
                final progress = offlineProvider.downloadProgress;
                final message =
                    offlineProvider.downloadMessage.isNotEmpty
                        ? offlineProvider.downloadMessage
                        : localeProvider.translate('downloading_route');

                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                      ),
                      const SizedBox(height: 20),
                      Text(message),
                      if (progress > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      );

      final success = await offlineProvider.downloadRoute(
        routeId,
        routeName,
        localeProvider.currentLangId,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? localeProvider.translate('route_downloaded_successfully')
                  : localeProvider.translate('error_downloading_route'),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteRoute(
    Map<String, dynamic> route,
    LocaleProvider localeProvider,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(localeProvider.translate('delete_route')),
            content: Text(
              '${localeProvider.translate('confirm_delete_route')} "${route['title']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(localeProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(localeProvider.translate('delete')),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      await _deleteRoute(
        route['route_id'].toString(),
        route['title'],
        localeProvider,
      );
    }
  }

  Future<void> _deleteRoute(
    String routeId,
    String routeName,
    LocaleProvider localeProvider,
  ) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await api.deleteRoute(routeId);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localeProvider.translate('route_deleted_successfully')}: $routeName',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Recargar la lista
          _loadMyRoutes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('error_deleting_route')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localeProvider.translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
