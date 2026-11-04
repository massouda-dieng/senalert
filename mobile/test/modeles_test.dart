import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalert_mobile/app.dart';
import 'package:senalert_mobile/core/api.dart';
import 'package:senalert_mobile/core/format.dart';
import 'package:senalert_mobile/core/models.dart';
import 'package:senalert_mobile/features/citoyen/report_screen.dart';
import 'package:senalert_mobile/ui/credits_photos.dart';

Map<String, dynamic> sos({double? lat}) => {
      'id': 7, 'reference': 'SOS-2026-000007', 'statut': 'nouveau', 'gravite': 'critique', 'latitude': lat, 'longitude': lat == null ? null : -17.4,
      'precision_gps': lat == null ? null : 12, 'region': 'dakar', 'region_libelle': 'Dakar', 'date_creation': '2026-10-29T10:00:00Z',
      'est_proprietaire': true, 'intervention': null, 'message': '',
    };

void main() {
  group('Modèle Dossier', () {
    test('SOS sans GPS : aucune position inventée', () {
      final d = Dossier.depuis(sos(), estSos: true);
      expect(d.lat, isNull);
      expect(d.titre, 'Alerte SOS');
      expect(d.chemin, '/alertes/sos/7/');
    });

    test('incident avec intervention et photos', () {
      final d = Dossier.depuis({
        ...sos(lat: 14.7), 'type_incident': 'incendie', 'categorie_libelle': 'Incendie', 'statut': 'resolu',
        'intervention': {'agent': 3, 'agent_nom': 'Agent de secours', 'compte_rendu': 'Feu maîtrisé'},
        'photos': [{'id': 1, 'url': '/api/incidents/7/photos/1/'}],
      }, estSos: false);
      expect(d.estClos, isTrue);
      expect(d.agentId, 3);
      expect(d.photos.single['url'], contains('/photos/1/'));
    });
  });

  group('Libellés', () {
    test('tous les statuts du cycle de vie ont un libellé', () {
      for (final s in ['nouveau', 'affecte', 'accepte', 'en_cours', 'resolu', 'refuse', 'annule']) {
        expect(statut(s).libelle, isNot(s));
      }
      expect(distance(2340), '2,3 km');
      expect(distance(80), '80 m');
    });
  });

  group('Conversion des erreurs API', () {
    final req = RequestOptions(path: '/x');
    test('coupure réseau', () {
      final e = Api.convertir(DioException(requestOptions: req, type: DioExceptionType.connectionError));
      expect(e.estReseau, isTrue);
      expect(e.message, contains('réseau'));
    });
    test('conflit de statut (409) et erreurs de champs', () {
      final e = Api.convertir(DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 409,
          data: {'detail': 'Le dossier a changé', 'code': 'conflit'})));
      expect(e.estConflit, isTrue);
      final v = Api.convertir(DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 400,
          data: {'detail': 'Email invalide', 'champs': {'email': ['Email invalide']}})));
      expect(v.erreurChamp('email'), 'Email invalide');
    });
    test('erreur serveur sans corps JSON', () {
      final e = Api.convertir(DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 502, data: '<html>')));
      expect(e.message, contains('serveur'));
    });
  });

  test('chaque rôle a son espace', () {
    expect(accueilPour('citoyen'), '/accueil');
    expect(accueilPour('agent'), '/agent');
    expect(accueilPour('superadmin'), '/supervision');
  });

  test('chaque photo d’illustration a un crédit de licence', () {
    expect(creditsPhotos.length, greaterThanOrEqualTo(9));
    for (final c in creditsPhotos.values) {
      expect(c, contains('Photo :'));
      expect(RegExp(r'CC|Public domain').hasMatch(c), isTrue);
    }
  });

  test('clés d’idempotence uniques', () {
    expect(nouvelleCle(), isNot(nouvelleCle()));
  });

  test('SOS : type d’urgence, structure destinataire et dates enregistrées par le serveur', () {
    final d = Dossier.depuis({...sos(lat: 14.7), 'type_urgence': 'incendie', 'type_urgence_libelle': 'Incendie',
        'structure': 179, 'structure_nom': 'Caserne Sapeurs Pompiers', 'date_modification': '2026-10-29T10:05:00Z'}, estSos: true);
    expect(d.typeUrgenceLibelle, 'Incendie');
    expect(d.structureNom, 'Caserne Sapeurs Pompiers');
    expect(d.modification!.isAfter(d.creation!), isTrue);
    expect(typesUrgence.keys, containsAll(['medicale', 'incendie', 'accident', 'agression']));
  });

  test('heures affichées à l’heure de Dakar, quel que soit le fuseau du téléphone', () {
    expect(heureDakar(DateTime.parse('2026-10-29T10:00:00+02:00')).hour, 8);
    expect(heureDakar(DateTime.parse('2026-10-29T10:00:00Z')).hour, 10);
  });

  test('photos : seuls JPEG, PNG et WEBP sont acceptés', () {
    expect(formatImageAccepte(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0])), isTrue);
    expect(formatImageAccepte(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])), isTrue);
    expect(formatImageAccepte(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)), isTrue);
    expect(formatImageAccepte(Uint8List.fromList('GIF89a......'.codeUnits)), isFalse);
    expect(formatImageAccepte(Uint8List.fromList('%PDF-1.7....'.codeUnits)), isFalse);
  });
}
