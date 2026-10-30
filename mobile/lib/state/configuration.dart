import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../core/api.dart';
import '../core/models.dart';

/// Configuration publique du serveur (catégories, régions, numéros vérifiés).
/// Conservée localement pour rester utilisable hors connexion.
class Configuration extends ChangeNotifier {
  List<Categorie> categories = [];
  List<Region> regions = [];
  List<NumeroUrgence> numeros = [];
  String avertissement = 'SenAlert ne remplace pas les services officiels de secours.';
  bool chargee = false;
  String? erreur;

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = await Api.instance.get<Map<String, dynamic>>('/configuration/');
      _appliquer(j);
      erreur = null;
      await prefs.setString('configuration', jsonEncode(j));
    } on ApiException catch (e) {
      erreur = e.message;
      final cache = prefs.getString('configuration');
      if (cache != null) _appliquer(jsonDecode(cache));
    }
    notifyListeners();
  }

  void _appliquer(Map<String, dynamic> j) {
    categories = (j['categories'] as List).map((c) => Categorie.depuis(c)).toList();
    regions = (j['regions'] as List).map((r) => Region.depuis(r)).toList();
    numeros = (j['numeros_urgence'] as List).map((n) => NumeroUrgence.depuis(n)).toList();
    avertissement = j['avertissement'] ?? avertissement;
    chargee = true;
  }

  Categorie? categorie(String? code) => categories.where((c) => c.code == code).firstOrNull;
  Region? region(String? code) => regions.where((r) => r.code == code).firstOrNull;
}
