import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'config.dart';

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// Accès GPS natif (Android + iOS).
class LocationService {
  /// Position actuelle. En mode démo, retombe sur Oran si le GPS est indisponible.
  static Future<LatLng> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationException('Activez la localisation (GPS) de votre téléphone.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw LocationException('DÉPANINI a besoin de votre position pour trouver les prestataires proches.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (e) {
      if (AppConfig.isDemo) return const LatLng(AppConfig.fallbackLat, AppConfig.fallbackLng);
      rethrow;
    }
  }

  /// Flux de positions (app Pro, en ligne ou en mission).
  static Stream<LatLng> stream({int distanceFilterMeters = 30}) => Geolocator.getPositionStream(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters),
      ).map((p) => LatLng(p.latitude, p.longitude));
}
