import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senalert_mobile/core/models.dart';

/// Réponses réelles de l'API (capturées sur le serveur local) : le modèle doit les lire sans erreur.
void main() {
  test('réponses réelles incidents et SOS', () {
    for (final (fichier, sos) in [('incidents', false), ('sos', true)]) {
      final j = jsonDecode(File('test/donnees/$fichier.json').readAsStringSync());
      for (final x in j['results']) {
        final d = Dossier.depuis(Map<String, dynamic>.from(x), estSos: sos);
        expect(d.reference, isNotEmpty);
      }
    }
  });
}
