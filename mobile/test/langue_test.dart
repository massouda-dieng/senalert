import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senalert_mobile/state/langue.dart';

void main() {
  test('la copie mobile des traductions est identique à traductions/wolof.json', () {
    final principal = jsonDecode(File('../traductions/wolof.json').readAsStringSync());
    final copie = jsonDecode(File('assets/traductions/wolof.json').readAsStringSync());
    expect(copie, principal, reason: 'Lancez ./run.sh traductions');
  });

  test('wolof seulement pour le citoyen, repli en français', () {
    final l = Langue.instance..definirPourTest({'Résolu': 'Jeex na', 'Bonjour {nom}': 'Na nga def {nom}', 'categorie:incendie': 'Safara'});
    expect(tr('Résolu'), 'Jeex na');
    expect(tr('Bonjour {nom}', {'nom': 'Awa'}), 'Na nga def Awa');
    expect(tr('Inconnu'), 'Inconnu');
    expect(l.categorie('incendie', 'Incendie'), 'Safara');
    l.role = 'agent';
    expect(tr('Résolu'), 'Résolu');
    l.definirPourTest(const {}, choix: 'fr');
  });
}
