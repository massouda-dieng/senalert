import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l'espace citoyen : « fr » ou « wo » (wolof), mémorisée sur l'appareil.
/// Les traductions viennent de assets/traductions/wolof.json (copie de traductions/wolof.json).
/// Pour les agents et superviseurs, l'application reste en français.
class Langue extends ChangeNotifier {
  static final instance = Langue();

  String choix = 'fr';
  String? role;
  Map<String, String> _wolof = {};

  bool get wolof => choix == 'wo' && role == 'citoyen';

  Future<void> charger() async {
    try {
      choix = (await SharedPreferences.getInstance()).getString('langue') ?? 'fr';
      final brut = jsonDecode(await rootBundle.loadString('assets/traductions/wolof.json')) as Map<String, dynamic>;
      _wolof = {for (final e in brut.entries) if (!e.key.startsWith('_')) e.key: '${e.value}'};
    } catch (_) {
      _wolof = {}; // fichier absent : tout reste en français
    }
  }

  Future<void> choisir(String nouvelle) async {
    choix = nouvelle;
    (await SharedPreferences.getInstance()).setString('langue', nouvelle);
    notifyListeners();
    WidgetsBinding.instance.reassembleApplication(); // textes lus au build : on redessine tout
  }

  String traduire(String fr, [Map<String, Object?>? valeurs]) {
    var texte = (wolof ? _wolof[fr] : null) ?? fr;
    valeurs?.forEach((k, v) => texte = texte.replaceAll('{$k}', '${v ?? ''}'));
    return texte;
  }

  String categorie(String? code, String libelle) => (wolof ? _wolof['categorie:$code'] : null) ?? libelle;

  /// Pour les tests.
  void definirPourTest(Map<String, String> traductions, {String choix = 'wo', String role = 'citoyen'}) {
    _wolof = traductions;
    this.choix = choix;
    this.role = role;
  }
}

/// Raccourci : texte dans la langue choisie (wolof seulement dans l'espace citoyen).
String tr(String fr, [Map<String, Object?>? valeurs]) => Langue.instance.traduire(fr, valeurs);
