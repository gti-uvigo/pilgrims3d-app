import 'dart:html' as html;

String getInitialLocation() {
  try {
    // En web con hash routing, la ruta real está en el fragment (hash)
    final hash = html.window.location.hash ?? '';
    print('🌐 Web hash: $hash');

    // Remover el # inicial si existe
    final path = hash.startsWith('#') ? hash.substring(1) : hash;

    // Si no hay hash, usar el pathname (para cuando se comparte con path routing)
    final finalPath =
        path.isEmpty ? (html.window.location.pathname ?? '/') : path;
    print('🌐 Web initial location: $finalPath');

    // Solo usar rutas públicas como initialLocation
    if (finalPath.startsWith('/poi/') ||
        finalPath == '/login' ||
        finalPath == '/terms' ||
        finalPath == '/privacy' ||
        finalPath == '/delete_account') {
      print('✅ Usando ruta inicial: $finalPath');
      return finalPath;
    }

    print('📍 Ruta no pública, usando /');
  } catch (e) {
    print('❌ Error obteniendo location: $e');
  }
  return '/';
}
