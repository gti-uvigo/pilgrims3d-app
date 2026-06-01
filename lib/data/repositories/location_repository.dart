import 'package:geolocator/geolocator.dart';

/// Repositorio que abstrae la obtención de la ubicación del dispositivo.
/// La UI no necesita saber que se usa el paquete 'geolocator'.
class LocationRepository {
  /// Obtiene la posición actual del usuario.
  /// Lanza una excepción si los permisos son denegados o el servicio está deshabilitado.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('El servicio de ubicación está deshabilitado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Los permisos de ubicación están denegados permanentemente.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }
}
