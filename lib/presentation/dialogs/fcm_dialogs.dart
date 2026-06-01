


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';

Future<void> getSOSdialog(BuildContext context, String? messageBody) async {
  final theme = Theme.of(context);
  final textStyles = theme.textTheme;
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

  // --- Parseo seguro de coordenadas ---
  String lat = 'Desconocida';
  String long = 'Desconocida';
  bool hasValidCoordinates = false;

  if (messageBody != null) {
    final parts = messageBody.split(',');
    if (parts.length == 2) {
      lat = parts[0].trim();
      long = parts[1].trim();
      // Verificación simple (en un caso real, validarías que sean números)
      if (lat.isNotEmpty && long.isNotEmpty) {
        hasValidCoordinates = true;
      }
    }
  }
  // --- Fin del parseo ---

  return showDialog(
    context: context,
    // Impedir que se cierre al tocar fuera (es una alerta crítica)
    barrierDismissible: false, 
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        localeProvider.translate('sos_alert_title'),
        textAlign: TextAlign.center,
        style: textStyles.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.red[700], // Un rojo fuerte y legible
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // Icono semántico y de alta visibilidad
          Icon(
            Icons.sos_rounded, 
            color: Colors.red[700],
            size: 50,
          ),
          const SizedBox(height: 24),
          Text(
            localeProvider.translate('sos_urgent_signal'),
            textAlign: TextAlign.center,
            style: textStyles.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            localeProvider.translate('sos_coordinates'),
            textAlign: TextAlign.center,
            style: textStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          // Destacar las coordenadas
          Text(
            '$lat, $long',
            textAlign: TextAlign.center,
            style: textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace', // Opcional: para coordenadas
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        // Botón secundario (Cerrar)
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
          },
          child: Text(localeProvider.translate('Close')),
        ),
        // Botón primario (Ir al mapa)
        FilledButton.icon(
          icon: const Icon(Icons.location_on_outlined),
          label: Text(localeProvider.translate('sos_go_to_map')),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red[700],
          ),
          // El botón se deshabilita si 'hasValidCoordinates' es false
          onPressed: hasValidCoordinates
            ? () {
                // Cerrar el diálogo antes de navegar
                Navigator.of(dialogContext).pop();
                // Usar el contexto original para navegar
                context.push(
                  '/navigationMap',
                  extra: {
                    'destinationLatitude': double.tryParse(lat),
                    'destinationLongitude': double.tryParse(long),
                    'destinationName': 'SOS Alert',
                  },
                );
              }
            : null,
          ),   ],
    ),
  );
}


Future<void> poiCreatedSuccessfully(BuildContext context) async {
  final theme = Theme.of(context);
  final textStyles = theme.textTheme;
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Título centrado
      title: Text(
        localeProvider.translate('poi_created_success'),
        textAlign: TextAlign.center,
        style: textStyles.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // Icono grande de éxito
          Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green[700],
            size: 50,
          ),
          const SizedBox(height: 24),
          // Mensaje principal
          Text(
            localeProvider.translate('poi_created_available'),
            textAlign: TextAlign.center,
            style: textStyles.bodyLarge,
          ),
          const SizedBox(height: 8),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
          },
          child: Text(
            localeProvider.translate('confirm'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    ),
  );
}


Future<void> poiInappropriateContent(BuildContext context, String? messageBody) async {
  // Obtener el tema y los estilos de texto del contexto principal
  final theme = Theme.of(context);
  final textStyles = theme.textTheme;
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

  // --- Lógica para "traducir" el messageBody ---
  // Esto es clave para una buena UX. Los mensajes de error de la API
  // (en inglés) no deben mostrarse directamente al usuario (en español).
  String reasonText;
  switch (messageBody) {
    case 'Title rejected by moderation.':
      reasonText = localeProvider.translate('poi_title_rejected');
      break;
    case 'Description rejected by moderation.':
      reasonText = localeProvider.translate('poi_description_rejected');
      break;
    case null:
    case '':
      // Fallback si no llega ningún mensaje
      reasonText = localeProvider.translate('poi_content_not_compliant');
      break;
    default:
      // Un fallback por si llega un mensaje que no esperamos pero que queremos mostrar
      reasonText = messageBody;
  }

  // Usamos return para que se pueda hacer 'await' correctamente
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Es más limpio poner el icono en el 'content' y usar el 'title' solo para el texto
      title: Text(
        localeProvider.translate('poi_content_rejected'),
        textAlign: TextAlign.center,
        style: textStyles.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min, // Para que la columna no se expanda
        children: [
          const SizedBox(height: 16),
          // Un icono de advertencia es más apropiado que 'error' para moderación
          Icon(
            Icons.warning_amber_rounded,
            color: const Color.fromARGB(255, 245, 0, 0), // Un naranja más nítido
            size: 50,
          ),
          const SizedBox(height: 24),
          // Mensaje principal que explica la situación
          Text(
            localeProvider.translate('poi_rejection_reason'),
            textAlign: TextAlign.center,
            style: textStyles.bodyLarge, // Buen tamaño para el cuerpo
          ),
          const SizedBox(height: 16),
          // El motivo específico (nuestro 'reasonText')
          // Lo ponemos en un contenedor para destacarlo sutilmente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 0, 0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reasonText,
              textAlign: TextAlign.center,
              style: textStyles.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 230, 0, 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center, // Centrar el botón
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
          },
          // "Entendido" es mejor UX que "Cerrar" porque implica acuse de recibo
          child: Text(
            localeProvider.translate('understand'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    ),
  );
}
    