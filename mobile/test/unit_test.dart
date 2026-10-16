import 'package:flutter_test/flutter_test.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IncidentModel Unit Tests', () {
    test('Incident.fromJson parses valid JSON data accurately', () {
      final json = {
        'id': 101,
        'type_incident': 'accident',
        'description': 'Collision sur VDN',
        'region': 'dakar',
        'latitude': 14.7167,
        'longitude': -17.4667,
        'statut': 'en_cours',
        'date_creation': '2026-08-08T22:00:00Z',
      };

      final incident = Incident.fromJson(json);

      expect(incident.id, 101);
      expect(incident.type, 'accident');
      expect(incident.description, 'Collision sur VDN');
      expect(incident.location, 'dakar');
      expect(incident.status, 'en_cours');
      expect(incident.latitude, 14.7167);
      expect(incident.longitude, -17.4667);
    });

    test('Incident statusLabel and typeIcon return expected values', () {
      final incidentAccident = Incident(
        id: 1,
        type: 'Accident',
        description: 'Test',
        location: 'Dakar',
        latitude: 14.7,
        longitude: -17.4,
        status: 'en_cours',
        date: 'A l\'instant',
      );

      expect(incidentAccident.typeIcon, '🚗');
      expect(incidentAccident.statusLabel, '🚒 Urgence Acceptée / En route');
    });

    // ===== NOUVEAUX TESTS ASMAOU — Statuts agent =====

    test('Incident avec statut nouveau a le bon label', () {
      final inc = Incident(
        id: 2, type: 'incendie', description: 'Feu quartier', location: 'thies',
        latitude: 14.79, longitude: -16.93, status: 'nouveau', date: 'Maintenant',
      );
      expect(inc.statusLabel, contains('attente'));
    });

    test('Incident avec statut resolu a le bon label', () {
      final inc = Incident(
        id: 3, type: 'inondation', description: 'Route inondée', location: 'kaolack',
        latitude: 14.15, longitude: -16.07, status: 'resolu', date: 'Hier',
      );
      expect(inc.statusLabel, contains('Traitée'));
    });

    test('Incident avec statut refuse a le bon label', () {
      final inc = Incident(
        id: 4, type: 'autre', description: 'Signalement invalide', location: 'dakar',
        latitude: 14.69, longitude: -17.44, status: 'refuse', date: 'Il y a 2h',
      );
      expect(inc.statusLabel, contains('Classée'));
    });

    test('Urgence médicale a la bonne icône', () {
      final inc = Incident(
        id: 5, type: 'urgence_medicale', description: 'Malaise', location: 'dakar',
        latitude: 14.7, longitude: -17.4, status: 'nouveau', date: 'Maintenant',
      );
      expect(inc.typeIcon, '🏥');
    });

    test('Incident incendie a la bonne icône', () {
      final inc = Incident(
        id: 6, type: 'incendie', description: 'Feu', location: 'saint-louis',
        latitude: 16.02, longitude: -16.49, status: 'en_cours', date: 'Maintenant',
      );
      expect(inc.typeIcon, '🔥');
    });

    test('Incident fromJson gère latitude/longitude en String', () {
      final json = {
        'id': 7,
        'type_incident': 'accident',
        'description': 'Test string coords',
        'region': 'dakar',
        'latitude': '14.7167',
        'longitude': '-17.4667',
        'statut': 'nouveau',
        'date_creation': '2026-10-16T10:00:00Z',
      };
      final incident = Incident.fromJson(json);
      expect(incident.latitude, closeTo(14.7167, 0.0001));
      expect(incident.longitude, closeTo(-17.4667, 0.0001));
    });
  });

  group('IncidentProvider Logic Tests', () {
    test('IncidentProvider initializes with fallback demo data on network error', () async {
      final provider = IncidentProvider();
      await provider.fetchIncidents();

      expect(provider.incidents.length, greaterThanOrEqualTo(3));
      expect(provider.isLoading, isFalse);
    });

    test('IncidentProvider a des incidents après initialisation', () async {
      final provider = IncidentProvider();
      await Future.delayed(const Duration(seconds: 2));
      expect(provider.incidents, isNotEmpty);
      expect(provider.isLoading, isFalse);
    });
  });
}
