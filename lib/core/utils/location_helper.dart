import 'package:geolocator/geolocator.dart';

Future<Position> determinePosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('El servicio de ubicación está deshabilitado.');
  }
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Los permisos de ubicación fueron denegados.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Los permisos de ubicación están denegados permanentemente.');
  }
  return await Geolocator.getCurrentPosition();
}
