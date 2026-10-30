import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

// ── Modèle ZoneRisque ──────────────────────────────────────────────────────

class ZoneRisque {
  final String region;
  final double score;
  final String niveau;
  final int totalIncidents;
  final List<String> typesPredominants;
  final int incidentsRecents;

  ZoneRisque({
    required this.region,
    required this.score,
    required this.niveau,
    required this.totalIncidents,
    required this.typesPredominants,
    required this.incidentsRecents,
  });

  factory ZoneRisque.fromJson(Map<String, dynamic> json) {
    return ZoneRisque(
      region: json['region'],
      score: (json['score'] as num).toDouble(),
      niveau: json['niveau'],
      totalIncidents: json['total_incidents'],
      typesPredominants: List<String>.from(json['types_predominants']),
      incidentsRecents: json['incidents_recents'],
    );
  }

  String get niveauEmoji {
    switch (niveau) {
      case 'critique': return '🔴';
      case 'eleve':    return '🟠';
      case 'moyen':    return '🟡';
      default:         return '🟢';
    }
  }
}

// ── Service IA ─────────────────────────────────────────────────────────────

class IaService {
  final http.Client client;
  final String baseUrl;

  IaService({required this.client, this.baseUrl = 'http://127.0.0.1:8000'});

  Future<List<ZoneRisque>> getZonesRisque({String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await client.get(
      Uri.parse('$baseUrl/api/analyse/zones-risque/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List zones = data['zones'];
      return zones.map((z) => ZoneRisque.fromJson(z)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Non authentifié');
    } else {
      throw Exception('Erreur serveur : ${response.statusCode}');
    }
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  final mockResponse = json.encode({
    'status': 'success',
    'total_zones_analysees': 2,
    'zones': [
      {
        'region': 'dakar',
        'score': 22.0,
        'niveau': 'critique',
        'total_incidents': 8,
        'types_predominants': ['inondation', 'incendie'],
        'incidents_recents': 5,
      },
      {
        'region': 'thies',
        'score': 9.0,
        'niveau': 'eleve',
        'total_incidents': 3,
        'types_predominants': ['accident'],
        'incidents_recents': 2,
      },
    ],
  });

  group('ZoneRisque.fromJson', () {
    test('parse correctement un JSON valide', () {
      final json = {
        'region': 'dakar',
        'score': 22.0,
        'niveau': 'critique',
        'total_incidents': 8,
        'types_predominants': ['inondation', 'incendie'],
        'incidents_recents': 5,
      };
      final zone = ZoneRisque.fromJson(json);
      expect(zone.region, 'dakar');
      expect(zone.score, 22.0);
      expect(zone.niveau, 'critique');
    });

    test('niveauEmoji retourne 🔴 pour critique', () {
      final zone = ZoneRisque(
        region: 'dakar', score: 20, niveau: 'critique',
        totalIncidents: 5, typesPredominants: [], incidentsRecents: 3,
      );
      expect(zone.niveauEmoji, '🔴');
    });

    test('niveauEmoji retourne 🟢 pour faible', () {
      final zone = ZoneRisque(
        region: 'kedougou', score: 1, niveau: 'faible',
        totalIncidents: 1, typesPredominants: [], incidentsRecents: 0,
      );
      expect(zone.niveauEmoji, '🟢');
    });
  });

  group('IaService.getZonesRisque', () {
    test('retourne une liste si 200 OK', () async {
      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });
      final service = IaService(client: mockClient);
      final zones = await service.getZonesRisque(token: 'fake_token');
      expect(zones.length, 2);
      expect(zones[0].region, 'dakar');
    });

    test('lève une exception si 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });
      final service = IaService(client: mockClient);
      expect(
        () => service.getZonesRisque(token: 'bad_token'),
        throwsA(isA<Exception>()),
      );
    });

    test('envoie le token JWT dans le header', () async {
      String? capturedAuth;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(mockResponse, 200);
      });
      final service = IaService(client: mockClient);
      await service.getZonesRisque(token: 'mon_token');
      expect(capturedAuth, 'Bearer mon_token');
    });
  });
}