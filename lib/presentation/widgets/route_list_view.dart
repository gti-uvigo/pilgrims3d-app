import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/providers/offline_provider.dart';
import 'package:pilgrims_3d/presentation/providers/connectivity_provider.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';
import 'package:pilgrims_3d/presentation/widgets/route_info_dialog.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:provider/provider.dart';

// Widget helper para mostrar el badge de dificultad
Widget _buildDifficultyBadge(String? difficulty, LocaleProvider localeProvider) {
  String difficultyValue = (difficulty ?? 'medium').toLowerCase();
  
  Color accentColor;
  IconData icon;
  String translationKey;
  
  switch (difficultyValue) {
    case 'easy':
      accentColor = const Color(0xFF66BB6A);
      icon = Icons.circle;
      translationKey = 'difficulty_easy';
      break;
    case 'hard':
      accentColor = const Color(0xFFEF5350);
      icon = Icons.circle;
      translationKey = 'difficulty_hard';
      break;
    case 'medium':
    default:
      accentColor = const Color(0xFFFFA726);
      icon = Icons.circle;
      translationKey = 'difficulty_medium';
      break;
  }
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: accentColor.withOpacity(0.6),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: accentColor),
        const SizedBox(width: 6),
        Text(
          localeProvider.translate(translationKey),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

class RouteListView extends StatelessWidget {
  final String ruta;
  final List cards;
  final void Function(Map<String, dynamic>) onCardTap;

  const RouteListView({
    super.key,
    required this.ruta,
    required this.cards,
    required this.onCardTap,
  });

  Future<void> _showRouteInfo(
    BuildContext context,
    String routeId,
    String routeName,
  ) async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    // Mostrar loading mientras se obtienen los datos
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Obtener datos de elevación desde el backend
      final elevationData = await fetchRouteElevationData(routeId);
      
      if (context.mounted) {
        // Cerrar el loading
        Navigator.pop(context);

        List<ElevationPoint> elevationPoints = [];
        
        if (elevationData.isNotEmpty) {
          elevationPoints = elevationData
              .map((coords) => ElevationPoint.fromList(coords))
              .toList();
        }

        // Mostrar el bottom sheet con la información
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RouteInfoBottomSheet(
            routeName: routeName,
            elevationPoints: elevationPoints,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Cerrar el loading
        Navigator.pop(context);
        
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localeProvider.translate('error_loading_route_info'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadRoute(
    BuildContext context,
    String routeId,
    String routeName,
  ) async {
    final offlineProvider = Provider.of<OfflineProvider>(
      context,
      listen: false,
    );
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    // Verificar si ya está descargada
    final isDownloaded = offlineProvider.isRouteDownloaded(
      routeId,
      localeProvider.currentLangId,
    );

    if (isDownloaded) {
      // Mostrar diálogo para eliminar
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

      if (shouldDelete == true) {
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Consumer<OfflineProvider>(
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
        Navigator.pop(context); // Cerrar diálogo de progreso

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localeProvider.translate('route_downloaded_successfully'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localeProvider.translate('error_downloading_route'),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final connectivityProvider =
        kIsWeb ? null : Provider.of<ConnectivityProvider>(context);

    final isOffline =
        kIsWeb ? false : (connectivityProvider?.isOffline ?? false);

    // Decide el número de columnas: 1 o 2 máximo
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
      itemCount: cards.length,
      itemBuilder: (context, index) {
        var card = cards[index];
        final routeId = card['route_id'].toString();

        if (kIsWeb) {
          return RepaintBoundary(
            key: ValueKey('web_$routeId'),
            child: _buildCard(context, card, false, true, localeProvider),
          );
        }

        // Usar RepaintBoundary y Selector para aislar completamente cada card
        return RepaintBoundary(
          key: ValueKey('route_$routeId'),
          child: _RouteCardItem(
            card: card,
            routeId: routeId,
            isOffline: isOffline,
            localeProvider: localeProvider,
            onCardTap: onCardTap,
            onDownloadTap: _downloadRoute,
            onInfoTap: _showRouteInfo,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> card,
    bool isDownloaded,
    bool isAvailable,
    LocaleProvider localeProvider, {
    Widget? imageWidget,
    Key? key,
  }) {
    // En web no hay opacidad, en app sí cuando no está disponible
    final cardOpacity = kIsWeb ? 1.0 : (isAvailable ? 1.0 : 0.5);

    return AbsorbPointer(
      key: key,
      absorbing: !isAvailable,
      child: Opacity(
        opacity: cardOpacity,
        child: GestureDetector(
          onTap: () {
            HapticService().light();
            onCardTap(card);
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
                  imageWidget ??
                      OfflineCachedImage(
                        imageUrl: "$baseUrl/images/${card["image_id"]}",
                        imageId: card["image_id"].toString(),
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Image.asset(
                              'images/aragon.jpg',
                              fit: BoxFit.cover,
                            ),
                      ),
                  Container(
                    color: Colors.black.withOpacity(isAvailable ? 0.15 : 0.7),
                    child: Stack(
                      children: [
                        ListTile(
                          title: Text(
                            (card["title"] ?? '').toString(),
                            style: TextStyle(
                              color:
                                  isAvailable ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black,
                                  offset: const Offset(0, 2),
                                ),
                                Shadow(
                                  blurRadius: 16.0,
                                  color: Colors.black,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                          trailing:
                              !kIsWeb && !isAvailable
                                  ? const Icon(
                                    Icons.cloud_off,
                                    color: Colors.redAccent,
                                    size: 28,
                                  )
                                  : null,
                        ),
                        // Badge de dificultad debajo del título
                        Positioned(
                          left: 16,
                          top: 48,
                          child: _buildDifficultyBadge(
                            card['difficulty']?.toString(),
                            localeProvider,
                          ),
                        ),
                        // Botón de descarga/eliminar en la esquina superior derecha
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
                                    card['route_id'].toString(),
                                    card['title'].toString(),
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
                        // Botón de información (i) en la esquina inferior izquierda
                        if (isAvailable)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  HapticService().medium();
                                  _showRouteInfo(
                                    context,
                                    card['route_id'].toString(),
                                    card['title'].toString(),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget separado para cada card que se optimiza independientemente
class _RouteCardItem extends StatelessWidget {
  final Map<String, dynamic> card;
  final String routeId;
  final bool isOffline;
  final LocaleProvider localeProvider;
  final void Function(Map<String, dynamic>) onCardTap;
  final Future<void> Function(BuildContext, String, String) onDownloadTap;
  final Future<void> Function(BuildContext, String, String) onInfoTap;

  const _RouteCardItem({
    required this.card,
    required this.routeId,
    required this.isOffline,
    required this.localeProvider,
    required this.onCardTap,
    required this.onDownloadTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    // Crear el widget de imagen una sola vez
    final imageWidget = OfflineCachedImage(
      key: ValueKey('image_$routeId'),
      imageUrl: "$baseUrl/images/${card["image_id"]}",
      imageId: card["image_id"].toString(),
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
      errorWidget:
          (context, url, error) =>
              Image.asset('images/aragon.jpg', fit: BoxFit.cover),
    );

    // Usar Selector para solo reconstruir cuando cambie el estado de esta ruta específica
    return Selector<OfflineProvider, bool>(
      selector:
          (_, provider) =>
              provider.isRouteDownloaded(routeId, localeProvider.currentLangId),
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, isDownloaded, child) {
        final isAvailable = !isOffline || isDownloaded;
        final cardOpacity = isAvailable ? 1.0 : 0.5;

        return AbsorbPointer(
          absorbing: !isAvailable,
          child: Opacity(
            opacity: cardOpacity,
            child: GestureDetector(
              onTap: () {
                HapticService().light();
                onCardTap(card);
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
                      child!, // La imagen que no se reconstruye
                      Container(
                        color: Colors.black.withOpacity(
                          isAvailable ? 0.15 : 0.7,
                        ),
                        child: Stack(
                          children: [
                            ListTile(
                              title: Text(
                                (card["title"] ?? '').toString(),
                                style: TextStyle(
                                  color:
                                      isAvailable
                                          ? Colors.white
                                          : Colors.white70,
                                ),
                              ),
                              trailing:
                                  !isAvailable
                                      ? const Icon(
                                        Icons.cloud_off,
                                        color: Colors.redAccent,
                                        size: 28,
                                      )
                                      : null,
                            ),
                            // Badge de dificultad debajo del título
                            Positioned(
                              left: 16,
                              top: 48,
                              child: _buildDifficultyBadge(
                                card['difficulty']?.toString(),
                                localeProvider,
                              ),
                            ),
                            // Botón de descarga/eliminar
                            if (isAvailable)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      HapticService().medium();
                                      onDownloadTap(
                                        context,
                                        routeId,
                                        card['title'].toString(),
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
                                            : Icons
                                                .download_for_offline_outlined,
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
                            // Botón de información (i)
                            if (isAvailable)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      HapticService().medium();
                                      onInfoTap(
                                        context,
                                        routeId,
                                        card['title'].toString(),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.info_outline,
                                        color: Colors.white70,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: imageWidget,
    );
  }
}
