import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pilgrims_3d/presentation/providers/connectivity_provider.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:provider/provider.dart';
// Importa tu pantalla AR aquí si la tienes

class MapFloatingButtons extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onLocatePressed;
  final VoidCallback? onToggleRoute;
  final bool isRouteTrimmed;
  final VoidCallback? onTogglePoisAround;
  final bool poisAroundLoaded;
  final bool showPoisAround;
  
  // Elevation controls
  final VoidCallback? onToggleElevationColors;
  final bool elevationColorsEnabled;
  final bool elevationDataAvailable;
  final VoidCallback? onShowRouteInfo;

  const MapFloatingButtons({
    super.key,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onLocatePressed,
    this.onToggleRoute,
    this.isRouteTrimmed = false,
    this.onTogglePoisAround,
    this.poisAroundLoaded = false,
    this.showPoisAround = false,
    this.onToggleElevationColors,
    this.elevationColorsEnabled = false,
    this.elevationDataAvailable = false,
    this.onShowRouteInfo,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline =
        !kIsWeb && Provider.of<ConnectivityProvider>(context).isOffline;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExpanded) ...[
            // Si tienes pantalla AR, descomenta y ajusta el import y el builder
            FloatingActionButton(
              heroTag: 'btnLocate',
              onPressed: () {
                HapticService().medium();
                onLocatePressed();
              },
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(height: 10),
            if (onToggleRoute != null) ...[
              FloatingActionButton(
                heroTag: 'btnToggleRoute',
                onPressed: () {
                  HapticService().light();
                  onToggleRoute!();
                  // Si manejas el estado aquí, podrías añadir un setState(() => _isRouteTrimmed = !_isRouteTrimmed);
                },
                // El color azul que ya tenías es perfecto para acciones de mapa
                backgroundColor: Colors.blue[700],
                child: Icon(
                  // Si la ruta ya está recortada, mostramos el icono de "toda la ruta" (recorrer)
                  // Si no está recortada, mostramos el de "enfocar tramo"
                  isRouteTrimmed ? Icons.polyline : Icons.route,
                  color: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (onTogglePoisAround != null && !isOffline)
              FloatingActionButton(
                heroTag: 'btnTogglePoisAround',
                onPressed:
                    poisAroundLoaded
                        ? () {
                          HapticService().light();
                          onTogglePoisAround!();
                        }
                        : null,
                backgroundColor:
                    showPoisAround
                        ? Colors.orange[700]
                        : (poisAroundLoaded ? Colors.orange[300] : Colors.grey),
                child: Icon(
                  showPoisAround
                      ? Icons
                          .layers // Indica que la "capa" de puntos está puesta
                      : Icons
                          .layers_outlined, // Indica que está disponible pero oculta
                  color: Colors.white,
                ),
              ),
            const SizedBox(height: 10),
            // Botón para toggle de colores de elevación - COMENTADO: colores siempre activados
            // if (onToggleElevationColors != null && elevationDataAvailable)
            //   FloatingActionButton(
            //     heroTag: 'btnToggleElevationColors',
            //     onPressed: () {
            //       HapticService().light();
            //       onToggleElevationColors!();
            //     },
            //     backgroundColor:
            //         elevationColorsEnabled ? Colors.green[700] : Colors.green[300],
            //     child: Icon(
            //       elevationColorsEnabled
            //           ? Icons.landscape
            //           : Icons.landscape_outlined,
            //       color: Colors.white,
            //     ),
            //   ),
            // if (onToggleElevationColors != null && elevationDataAvailable)
            //   const SizedBox(height: 10),
            // Botón de info de ruta
            if (onShowRouteInfo != null && elevationDataAvailable)
              FloatingActionButton(
                heroTag: 'btnShowRouteInfo',
                onPressed: () {
                  HapticService().light();
                  onShowRouteInfo!();
                },
                backgroundColor: Colors.purple[700],
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                ),
              ),
            if (onShowRouteInfo != null && elevationDataAvailable)
              const SizedBox(height: 10),
          ],
          FloatingActionButton(
            heroTag: 'btnExpand',
            onPressed: () {
              HapticService().light();
              onToggleExpand();
            },
            child: Icon(isExpanded ? Icons.close : Icons.menu),
          ),
        ],
      ),
    );
  }
}
