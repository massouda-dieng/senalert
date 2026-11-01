import 'package:flutter/material.dart';

import 'jetons.g.dart';

export 'jetons.g.dart';

/// Couleurs de l'application. Les valeurs viennent de design/couleurs.json (voir jetons.g.dart), partagé avec le web.
/// Bleu marine : identité ; orange : vigilance ; rouge : urgence et SOS uniquement ; vert : réussite.
class AppColors {
  static const Color marine950 = Jetons.marine950;
  static const Color marine900 = Jetons.marine900;
  static const Color marine800 = Jetons.marine800;
  static const Color marine700 = Jetons.marine700;
  static const Color marine600 = Jetons.marine600;
  static const Color marine500 = Jetons.marine500;
  static const Color marine100 = Jetons.marine100;
  static const Color marine50 = Jetons.marine50;

  static const Color orange = Jetons.orange;
  static const Color orangeFonce = Jetons.orangeFonce;
  static const Color orangeClair = Jetons.orangeClair;

  static const Color rouge = Jetons.rouge;
  static const Color rougeFonce = Jetons.rougeFonce; // petit texte blanc sur rouge : contraste AA

  /// Mode sombre actif (piloté par state/apparence.dart ; l'application est reconstruite au changement).
  static bool sombre = false;

  // Surfaces et texte : dépendent du thème clair / sombre
  static Color get background => sombre ? Jetons.douceSombre : Jetons.douceClair;
  static Color get white => sombre ? Jetons.surfaceSombre : Jetons.surfaceClair;
  static Color get surfaceSubtle => sombre ? Jetons.subtileSombre : Jetons.subtileClair;
  static Color get border => sombre ? Jetons.bordSombre : Jetons.bordClair;
  static Color get textDark => sombre ? Jetons.texteSombre : Jetons.texteClair;
  static Color get textGrey => sombre ? Jetons.texteDouxSombre : Jetons.texteDouxClair;
  static Color get textMuted => sombre ? Jetons.textePaleSombre : Jetons.textePaleClair;

  // États
  static const Color success = Jetons.vertFonce;
  static const Color warning = Jetons.orangeFonce;
  static const Color info = Jetons.marine600;

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [marine900, marine800, marine700]);
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [rouge, rougeFonce]);
}
