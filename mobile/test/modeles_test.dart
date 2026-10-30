import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalert_mobile/app.dart';
import 'package:senalert_mobile/core/api.dart';
import 'package:senalert_mobile/core/format.dart';
import 'package:senalert_mobile/core/models.dart';

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

  test('clés d’idempotence uniques', () {
    expect(nouvelleCle(), isNot(nouvelleCle()));
  });
}
