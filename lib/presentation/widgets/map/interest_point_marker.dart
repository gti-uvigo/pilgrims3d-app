import 'package:pilgrims_3d/core/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';

class InterestPointMarker extends Marker {
  InterestPointMarker({
    required Map<String, dynamic> point,
    required BuildContext context,
  }) : super(
          key: ValueKey('poi_marker_${point['id']}'),
          point: _parseLatLng(point),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              HapticService().light();
              _showInterestPointOverlay(context, point);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: OfflineCachedImage(
                      key: ValueKey('poi_image_${point['id']}'),
                      imageUrl: "$baseUrl/images/${point['image_id']}",
                      imageId: point['image_id'].toString(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('InterestPointMarker: failed to load image $url — $error');
                        return Image.asset(
                          'images/default_image.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}

void _showInterestPointOverlay(BuildContext context, Map<String, dynamic> point) {
  final overlay = Overlay.of(context);
  OverlayEntry? overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              overlayEntry?.remove();
            },
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        Positioned(
          top: 50,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: OfflineCachedImage(
                        imageUrl: "$baseUrl/images/${point['image_id']}",
                        imageId: point['image_id'].toString(),
                        height: 150,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey, size: 50)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DescriptionWidget(poiId: point['id']?.toString()),
                    const SizedBox(height: 10),
                    if (point['address'] != null) ...[
                      Text('Address: ${point['address']}'),
                      const SizedBox(height: 5),
                    ],
                    if (point['website'] != null) ...[
                      InkWell(
                        onTap: () {
                          launchUrl(Uri.parse(point['website']));
                        },
                        child: Text(
                          'Website: ${point['website']}',
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  overlay.insert(overlayEntry);
}

// Helper para parsear LatLng de manera segura
LatLng _parseLatLng(Map<String, dynamic> point) {
  try {
    final lat = point['latitude'];
    final lng = point['longitude'];
    
    if (lat == null || lng == null) {
      debugPrint('⚠️  POI sin coordenadas: ${point['name'] ?? point['title'] ?? 'Sin nombre'}');
      return LatLng(0, 0);
    }
    
    double latitude;
    double longitude;
    
    if (lat is double) {
      latitude = lat;
    } else if (lat is int) {
      latitude = lat.toDouble();
    } else {
      latitude = double.parse(lat.toString());
    }
    
    if (lng is double) {
      longitude = lng;
    } else if (lng is int) {
      longitude = lng.toDouble();
    } else {
      longitude = double.parse(lng.toString());
    }
    
    return LatLng(latitude, longitude);
  } catch (e) {
    debugPrint('❌ Error parseando coordenadas del POI: $e');
    debugPrint('   POI data: $point');
    return LatLng(0, 0);
  }
}

// Widget para cargar la descripción del POI de forma asíncrona
class _DescriptionWidget extends StatelessWidget {
  final String? poiId;

  const _DescriptionWidget({this.poiId});

  @override
  Widget build(BuildContext context) {
    if (poiId == null) {
      return const Text(
        'No description available.',
        textAlign: TextAlign.justify,
        style: TextStyle(fontSize: 16),
      );
    }

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final langCode = localeProvider.currentLangId;

    return FutureBuilder<String>(
      future: moreInfoPois(poiId!, langCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Text(
            'Error loading description: ${snapshot.error}',
            textAlign: TextAlign.justify,
            style: const TextStyle(fontSize: 16, color: Colors.red),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Text(
            snapshot.data!,
            textAlign: TextAlign.justify,
            style: const TextStyle(fontSize: 16),
          );
        } else {
          return const Text(
            'No description available.',
            textAlign: TextAlign.justify,
            style: TextStyle(fontSize: 16),
          );
        }
      },
    );
  }
}
