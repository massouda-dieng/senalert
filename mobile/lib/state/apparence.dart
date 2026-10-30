import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';

/// Apparence : « systeme », « clair » ou « sombre », mémorisée sur l'appareil.
class Apparence extends ChangeNotifier with WidgetsBindingObserver {
  String mode = 'systeme';

  Future<void> charger() async {
    mode = (await SharedPreferences.getInstance()).getString('apparence') ?? 'systeme';
    WidgetsBinding.instance.addObserver(this);
    _appliquer();
  }

  bool get sombre => mode == 'sombre' ||
      (mode == 'systeme' && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  Future<void> choisir(String nouveau) async {
    mode = nouveau;
    (await SharedPreferences.getInstance()).setString('apparence', nouveau);
    _appliquer();
  }

  void _appliquer() {
    if (AppColors.sombre == sombre) { notifyListeners(); return; }
    AppColors.sombre = sombre;
    notifyListeners();
    // Les couleurs du kit sont lues au moment du build : on redessine tout l'arbre.
    WidgetsBinding.instance.reassembleApplication();
  }

  @override
  void didChangePlatformBrightness() { if (mode == 'systeme') _appliquer(); }
}
