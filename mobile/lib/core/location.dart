import 'package:geolocator/geolocator.dart';

/// Résultat d'une demande de position : soit des coordonnées avec précision,
/// soit un message explicite. Ne lève jamais d'exception.
class Position2 {
  final double? lat;
  final double? lng;
  final double? precision;
  final String? erreur;
  final bool reglagesRequis;
  const Position2({this.lat, this.lng, this.precision, this.erreur, this.reglagesRequis = false});
  bool get ok => lat != null;
}

class Localisation {
  static Future<Position2> lire({Duration delai = const Duration(seconds: 12)}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Position2(erreur: 'La localisation de l’appareil est désactivée.', reglagesRequis: true);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        return const Position2(erreur: 'Autorisation de localisation refusée.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const Position2(
            erreur: 'Localisation bloquée : autorisez-la dans les réglages de l’application.', reglagesRequis: true);
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: delai));
      return Position2(lat: p.latitude, lng: p.longitude, precision: p.accuracy);
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) return Position2(lat: p.latitude, lng: p.longitude, precision: p.accuracy);
      } catch (_) {}
      return const Position2(erreur: 'Position introuvable pour le moment.');
    }
  }

  static Future<void> ouvrirReglages() => Geolocator.openAppSettings();
}
