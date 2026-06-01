

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';

Future<void> showDisclaimerDialog(BuildContext context) async {
    final localeProvider = context.read<LocaleProvider>();
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(localeProvider.translate('disclaimer_title')),
        content: SingleChildScrollView(
          // Para evitar overflow
          child: Text(localeProvider.translate('disclaimer_body')),
        ),
        actions: [
          TextButton(
            // El pop es más correcto que go si solo quieres cerrar el diálogo.
            // La navegación a '/' se hará en el callback del login.
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localeProvider.translate('accept')),
          ),
        ],
      ),
    );
  }


  Future<void> creatingPoiDialog(BuildContext context) async {
    final localeProvider = context.read<LocaleProvider>();
    return await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) {
                        return PopScope(
                          canPop: false,
                          child: Center(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(localeProvider.translate('creating_poi')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
  }



Future<void> testingAndCreatingPoiDialog(BuildContext context) async {
  // El 'response' se imprime en la consola para depuración,
  // pero no se lo mostramos al usuario para una mejor UX.
  // print("Respuesta del servidor (debug): $response");
  final localeProvider = context.read<LocaleProvider>();

  return showDialog(
    context: context,
    // barrierDismissible: false, // Opcional: impide cerrar el diálogo tocando fuera
    builder: (BuildContext dialogContext) {
      final theme = Theme.of(context);
      return AlertDialog(
        // Añadimos bordes redondeados
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        // No usamos el 'title' por defecto para controlar mejor el layout
        title: null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Un icono da feedback visual inmediato
            Icon(
              Icons.rate_review_outlined, // Icono de "revisión"
              color: theme.colorScheme.primary, // Usa el color primario de tu tema
              size: 50,
            ),
            const SizedBox(height: 24),
            // Un título claro y centrado
            Text(
              localeProvider.translate('submitted_for_review_title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Un texto descriptivo que explica qué pasará ahora
            Text(
              localeProvider.translate('submitted_for_review_desc'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center, // Centra el botón
        actions: [
          TextButton(
            child: Text(localeProvider.translate('understand'), style: const TextStyle(fontSize: 16)),
            onPressed: () {
              // --- ¡CORRECCIÓN IMPORTANTE! ---
              // 1. Cierra el diálogo
              Navigator.of(dialogContext).pop();
              // 2. Navega a la home (usando el context original)
              context.go('/'); // o context.push('/') dependiendo de tu stack
            },
          ),
        ],
      );
    },
  );
}


  Future<void> errorCreatingPoiDialog(BuildContext context, String error) async {
    final localeProvider = context.read<LocaleProvider>();
    return await showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: Text(localeProvider.translate('Error')),
                            content: SingleChildScrollView(
                              child: Text(localeProvider.translate('error_creating_poi', args: {'error': error})),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: Text(localeProvider.translate('Close')),
                              ),
                            ],
                          );
                        },
                      );
  }