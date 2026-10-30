import 'package:flutter/material.dart';

/// Palette SenAlert « Sénégal vibrant » — mêmes jetons que le web (tailwind.config.js).
/// Vert du drapeau : identité ; jaune : accents ; rouge : réservé au SOS et à l'urgence.
class AppColors {
  // Vert (identité, navigation, actions principales)
  static const Color vert950 = Color(0xFF00210F);
  static const Color vert900 = Color(0xFF003A1B);
  static const Color vert800 = Color(0xFF005527);
  static const Color vert700 = Color(0xFF006E33);
  static const Color vert600 = Color(0xFF00853F);
  static const Color vert100 = Color(0xFFD3F0DF);
  static const Color vert50 = Color(0xFFECF8F1);

  // Jaune
  static const Color jaune = Color(0xFFFDEF42);
  static const Color jauneFonce = Color(0xFF8A6D00);
  static const Color jauneClair = Color(0xFFFFF9D1);

  // Rouge (SOS uniquement)
  static const Color crimson = Color(0xFFE31B23);
  static const Color crimsonDeep = Color(0xFFB5121A);

  /// Mode sombre actif (piloté par state/apparence.dart ; l'application est reconstruite au changement).
  static bool sombre = false;

  // Surfaces et texte : dépendent du thème clair / sombre
  static Color get background => sombre ? const Color(0xFF0B110E) : const Color(0xFFF8F7F1);
  static Color get white => sombre ? const Color(0xFF141C18) : const Color(0xFFFFFFFF);
  static Color get surfaceSubtle => sombre ? const Color(0xFF1C2620) : const Color(0xFFF1EFE6);
  static Color get border => sombre ? const Color(0xFF2A362F) : const Color(0xFFE7E4D8);
  static Color get textDark => sombre ? const Color(0xFFE8EEEA) : const Color(0xFF10231A);
  static Color get textGrey => sombre ? const Color(0xFFA8B6AE) : const Color(0xFF53645B);
  static Color get textMuted => sombre ? const Color(0xFF7D8B83) : const Color(0xFF8A978F);

  // États
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFC2410C);
  static const Color info = Color(0xFF1D4ED8);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [vert950, vert800, vert700]);
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2434A), crimson, crimsonDeep]);
}
