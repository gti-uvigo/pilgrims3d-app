import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';

class MapCurrentLocationMarker extends Marker {
  MapCurrentLocationMarker({
    required LatLng position,
    required BuildContext context,
  }) : super(
          point: position,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              HapticService().light();
              _showCurrentLocationOverlay(context);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withAlpha(76),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4285F4),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
}

void _showCurrentLocationOverlay(BuildContext context) {
  final overlay = Overlay.of(context);
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).size.height / 2 - 100,
      left: MediaQuery.of(context).size.width / 2 - 150,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localeProvider.translate('Current Location'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                localeProvider.translate('This is your current location'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  overlayEntry.remove();
                },
                child: Text(localeProvider.translate('Close')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
}
